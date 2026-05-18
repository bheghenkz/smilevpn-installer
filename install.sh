#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive

SMILEVPN_STATUS_FILE="/root/smilevpn-status"
echo "RUNNING" > "$SMILEVPN_STATUS_FILE"
trap 'echo "FAILED" > "$SMILEVPN_STATUS_FILE"' ERR

DOMAIN=$1
CF_API_TOKEN="${CF_API_TOKEN:-$2}"

if [ -f ".env" ]; then
    set -a
    . ./.env
    set +a
fi

if [ -z "$DOMAIN" ]; then
    echo "Usage: bash install.sh domain.com"
    exit 1
fi

echo "🚀 Installing SmileVPN on $DOMAIN"

if ! command -v apt >/dev/null 2>&1; then
    echo "❌ Unsupported OS. Installer ini untuk Debian/Ubuntu VPS."
    exit 1
fi

echo "🧹 Removing conflicting web server..."
systemctl stop apache2 2>/dev/null || true
systemctl disable apache2 2>/dev/null || true
apt-get remove --purge -y apache2 apache2-bin apache2-data apache2-utils 2>/dev/null || true

echo "📦 Installing packages..."
apt-get update -y
apt-get install -y curl wget unzip nginx ca-certificates socat cron openssl jq

# Restore missing nginx config files if VPS was cleaned manually
apt-get install -y --reinstall -o Dpkg::Options::="--force-confmiss" nginx nginx-common || true
mkdir -p /etc/nginx /etc/nginx/sites-available /etc/nginx/sites-enabled /etc/nginx/conf.d /var/log/nginx
touch /var/log/nginx/access.log /var/log/nginx/error.log

echo "📁 Setup folders..."
mkdir -p /etc/xray
mkdir -p /etc/xray/ssl
mkdir -p /usr/local/etc/xray
mkdir -p /var/log/xray
mkdir -p /var/www/html

# IPv6 safe mode: default OFF to prevent IPv6 leak/routing issues.
# Enable manually with: ENABLE_IPV6=true bash install.sh domain.com
ENABLE_IPV6="${ENABLE_IPV6:-false}"
if [ "$ENABLE_IPV6" != "true" ]; then
    echo "🌐 Disabling IPv6 safe mode..."
    cat >/etc/sysctl.d/99-smilevpn-disable-ipv6.conf <<EOF
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
    sysctl --system >/dev/null 2>&1 || true
else
    echo "🌐 IPv6 enabled by admin"
fi

echo "$DOMAIN" > /etc/xray/domain

SERVER_IP="$(curl -4 -s https://ipv4.icanhazip.com | tr -d '\n' || true)"
[ -n "$SERVER_IP" ] || SERVER_IP="$(curl -s https://api.ipify.org || true)"
[ -n "$SERVER_IP" ] || SERVER_IP="$(hostname -I | awk '{print $1}')"

curl -s https://ipinfo.io/org | sed 's/^AS[0-9]* //g' > /etc/xray/isp || true
curl -s --max-time 5 "https://ipinfo.io/${SERVER_IP}/city" > /etc/xray/city || true
[ -s /etc/xray/isp ] || echo "Unknown ISP" > /etc/xray/isp
[ -s /etc/xray/city ] || echo "Unknown City" > /etc/xray/city

echo "$SERVER_IP" > /etc/xray/ip
touch /var/log/xray/access.log
touch /var/log/xray/error.log

SSL_MODE="${SSL_MODE:-certbot}"

if [ "$SSL_MODE" = "cloudflare" ]; then
    echo "☁️ Installing Cloudflare Origin SSL..."

    if [ -f "ssl/fullchain.pem" ] && [ -f "ssl/privkey.pem" ]; then
        echo "✅ Using local Cloudflare SSL files..."
        cp ssl/fullchain.pem /etc/xray/ssl/fullchain.pem
        cp ssl/privkey.pem /etc/xray/ssl/privkey.pem
    else
        echo "🔑 Local SSL not found, generating via Cloudflare API..."

        if [ -z "$CF_API_TOKEN" ]; then
            read -rp "Cloudflare API Token: " CF_API_TOKEN
        fi

        openssl genrsa -out /etc/xray/ssl/privkey.pem 2048
        openssl req -new -key /etc/xray/ssl/privkey.pem -out /tmp/smilevpn.csr -subj "/CN=$DOMAIN"

        CSR_JSON=$(python3 - <<PY2
import json
csr=open("/tmp/smilevpn.csr").read()
print(json.dumps(csr))
PY2
)

        RESPONSE=$(curl -sS -X POST "https://api.cloudflare.com/client/v4/certificates" \
          -H "Authorization: Bearer $CF_API_TOKEN" \
          -H "Content-Type: application/json" \
          --data "{
            \"hostnames\": [\"$DOMAIN\"],
            \"requested_validity\": 5475,
            \"request_type\": \"origin-rsa\",
            \"csr\": $CSR_JSON
          }")

        echo "$RESPONSE" > /tmp/smilevpn-cf-cert.json

        python3 - <<PY3
import json, sys
data=json.load(open("/tmp/smilevpn-cf-cert.json"))
if not data.get("success"):
    print("Cloudflare API error:")
    print(json.dumps(data, indent=2))
    sys.exit(1)
cert=data["result"]["certificate"]
open("/etc/xray/ssl/fullchain.pem","w").write(cert)
PY3
    fi

    chmod 644 /etc/xray/ssl/fullchain.pem
    chmod 600 /etc/xray/ssl/privkey.pem
    echo "✅ Cloudflare Origin SSL installed"

else
    echo "🔐 Installing Certbot SSL..."

    apt-get install -y certbot

    systemctl stop nginx 2>/dev/null || true

    certbot certonly --standalone \
      --non-interactive \
      --agree-tos \
      --register-unsafely-without-email \
      -d "$DOMAIN"

    mkdir -p /etc/xray/ssl

    cp "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" /etc/xray/ssl/fullchain.pem
    cp "/etc/letsencrypt/live/$DOMAIN/privkey.pem" /etc/xray/ssl/privkey.pem

    chmod 644 /etc/xray/ssl/fullchain.pem
    chmod 600 /etc/xray/ssl/privkey.pem

    echo "✅ Certbot SSL installed"
fi

echo "⚙️ Installing Xray Core..."
export TERM=xterm

if [ ! -f /etc/systemd/system/xray.service ]; then
    rm -f /usr/local/bin/xray
    rm -rf /etc/systemd/system/xray.service.d
fi

echo "⚙️ Installing Xray Core..."
export TERM=xterm

XRAY_INSTALLER_URL="https://github.com/XTLS/Xray-install/raw/main/install-release.sh"
XRAY_OK=0

for i in 1 2 3; do
    echo "Try installing Xray attempt $i..."
    if curl -L --connect-timeout 20 --retry 3 --retry-delay 5 -o /tmp/xray-install.sh "$XRAY_INSTALLER_URL" && bash /tmp/xray-install.sh install; then
        XRAY_OK=1
        break
    fi
    sleep 5
done

if [ "$XRAY_OK" != "1" ]; then
    echo "❌ Xray install failed: cannot download from GitHub"
    exit 1
fi


echo "⚙️ Installing Xray config..."
cp config/xray.json /etc/xray/config.json

sed -i "s|DOMAIN|$DOMAIN|g" /etc/xray/config.json
sed -i "s|__DOMAIN__|$DOMAIN|g" /etc/xray/config.json
sed -i "s|IP_ADDRESS|$SERVER_IP|g" /etc/xray/config.json
sed -i "s|__IP_ADDRESS__|$SERVER_IP|g" /etc/xray/config.json
sed -i "s|__SERVER_IP__|$SERVER_IP|g" /etc/xray/config.json

mkdir -p /usr/local/etc/xray
cp /etc/xray/config.json /usr/local/etc/xray/config.json
chmod 755 /usr/local/etc /usr/local/etc/xray
chmod 644 /usr/local/etc/xray/config.json

sed -i "s/__VLESS_SEED__/$(cat /proc/sys/kernel/random/uuid)/g" /etc/xray/config.json
sed -i "s/__VMESS_SEED__/$(cat /proc/sys/kernel/random/uuid)/g" /etc/xray/config.json
sed -i "s/__TROJAN_SEED__/$(cat /proc/sys/kernel/random/uuid)/g" /etc/xray/config.json
sed -i "s/__VLESS_GRPC_SEED__/$(cat /proc/sys/kernel/random/uuid)/g" /etc/xray/config.json
sed -i "s/__VMESS_GRPC_SEED__/$(cat /proc/sys/kernel/random/uuid)/g" /etc/xray/config.json
sed -i "s/__TROJAN_GRPC_SEED__/$(cat /proc/sys/kernel/random/uuid)/g" /etc/xray/config.json
sed -i "s/__SS_WS_SEED__/$(openssl rand -hex 8)/g" /etc/xray/config.json
sed -i "s/__SS_GRPC_SEED__/$(openssl rand -hex 8)/g" /etc/xray/config.json

REALITY_KEYS=$(xray x25519)
REALITY_PRIVATE=$(echo "$REALITY_KEYS" | awk -F': ' '/PrivateKey:/ {print $2}')
REALITY_PUBLIC=$(echo "$REALITY_KEYS" | awk -F': ' '/Password \(PublicKey\):/ {print $2}')

if [ -z "$REALITY_PRIVATE" ] || [ -z "$REALITY_PUBLIC" ]; then
    echo "❌ Failed to generate Reality keys"
    echo "$REALITY_KEYS"
    exit 1
fi

REALITY_SHORT=$(openssl rand -hex 4)

echo "$REALITY_PUBLIC" > /etc/xray/reality_public
echo "$REALITY_SHORT" > /etc/xray/reality_short

sed -i "s|__REALITY_SEED__|$(cat /proc/sys/kernel/random/uuid)|g" /etc/xray/config.json
sed -i "s|__REALITY_PRIVATE__|${REALITY_PRIVATE}|g" /etc/xray/config.json
sed -i "s|__REALITY_SHORT__|${REALITY_SHORT}|g" /etc/xray/config.json

mkdir -p /usr/local/etc/xray
cp /etc/xray/config.json /usr/local/etc/xray/config.json
chmod 755 /usr/local/etc /usr/local/etc/xray
chmod 644 /usr/local/etc/xray/config.json

mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled /etc/nginx/conf.d

if [ ! -f /etc/nginx/nginx.conf ]; then
cat >/etc/nginx/nginx.conf <<'NGINXCONF'
user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 768;
}

http {
    sendfile on;
    tcp_nopush on;
    types_hash_max_size 2048;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    gzip on;

    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
NGINXCONF
fi
echo "🌐 Installing Nginx config..."

# SmileVPN fix: reset nginx.conf so it does not include stale /etc/nginx/conf.d/xray.conf
rm -f /etc/nginx/conf.d/xray.conf
sed -i '/xray\.conf/d' /etc/nginx/nginx.conf 2>/dev/null || true

cat > /etc/nginx/nginx.conf <<'NGINXCONF'
user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 768;
    multi_accept on;
}

http {
    sendfile on;
    tcp_nopush on;
    types_hash_max_size 2048;
    server_tokens off;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    gzip on;

    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
NGINXCONF

sed "s/DOMAIN/$DOMAIN/g" config/nginx.conf > /etc/nginx/sites-enabled/default

echo "🔓 Opening firewall ports..."
if command -v ufw >/dev/null 2>&1; then
    ufw allow 22 || true
    ufw allow 80 || true
    ufw allow 443 || true
    ufw allow 8443/tcp || true
    ufw allow 2087/tcp || true
fi


echo "🛡️ Installing Fail2Ban SSH protection..."
apt-get install -y fail2ban

cat > /etc/fail2ban/jail.local <<'F2B'
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
findtime = 600
bantime = 3600
backend = systemd
F2B

systemctl enable fail2ban
systemctl restart fail2ban
echo "✅ Fail2Ban SSH protection active"



echo "🚀 Applying SmileVPN network optimization..."
cat > /etc/sysctl.d/99-smilevpn-tuning.conf <<'EOF'
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_mtu_probing=1
net.ipv4.tcp_window_scaling=1
net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.tcp_tw_reuse=1
net.ipv4.ip_local_port_range=10240 65535
net.core.rmem_max=67108864
net.core.wmem_max=67108864
net.ipv4.tcp_rmem=4096 87380 67108864
net.ipv4.tcp_wmem=4096 65536 67108864
EOF

sysctl --system || true
echo "✅ Network optimization active"
echo "🚀 Applying SmileVPN speed boost..."
bash scripts/smilevpn-speed-boost || true




echo "🚀 Applying SmileVPN tunnel limits..."
cat > /etc/security/limits.d/99-smilevpn.conf <<'EOF'
* soft nofile 1048576
* hard nofile 1048576
root soft nofile 1048576
root hard nofile 1048576
EOF

mkdir -p /etc/systemd/system.conf.d
cat > /etc/systemd/system.conf.d/99-smilevpn.conf <<'EOF'
[Manager]
DefaultLimitNOFILE=1048576
DefaultLimitNPROC=1048576
EOF

systemctl daemon-reexec || true
echo "✅ Tunnel limits active"


echo "📜 Installing SmileVPN account scripts..."
mkdir -p /usr/local/sbin/smilevpn
cp scripts/* /usr/local/sbin/smilevpn/
chmod +x /usr/local/sbin/smilevpn/*

for f in /usr/local/sbin/smilevpn/*; do
    name=$(basename "$f")
    ln -sf "$f" "/usr/local/bin/$name"
done

hash -r
echo "✅ Account scripts installed and linked"

echo "⏰ Installing cron jobs..."
cat > /etc/cron.d/smilevpn <<'CRON'
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
*/5 * * * * root /usr/local/sbin/smilevpn/xp >/dev/null 2>&1
* * * * * root /usr/local/sbin/smilevpn/limit-ip-check >/dev/null 2>&1
* * * * * root /usr/local/sbin/smilevpn/zivpn-expired-check >/dev/null 2>&1
CRON
chmod 644 /etc/cron.d/smilevpn

cat > /etc/cron.d/smilevpn-ssh-fast <<'CRON'
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

* * * * * root /usr/local/sbin/smilevpn/ssh-limit-ip-check >/dev/null 2>&1
* * * * * root sleep 10; /usr/local/sbin/smilevpn/ssh-limit-ip-check >/dev/null 2>&1
* * * * * root sleep 20; /usr/local/sbin/smilevpn/ssh-limit-ip-check >/dev/null 2>&1
* * * * * root sleep 30; /usr/local/sbin/smilevpn/ssh-limit-ip-check >/dev/null 2>&1
* * * * * root sleep 40; /usr/local/sbin/smilevpn/ssh-limit-ip-check >/dev/null 2>&1
* * * * * root sleep 50; /usr/local/sbin/smilevpn/ssh-limit-ip-check >/dev/null 2>&1
CRON
chmod 644 /etc/cron.d/smilevpn-ssh-fast
systemctl enable cron
systemctl restart cron
echo "✅ Cron jobs installed"

echo "🔐 Preparing SSH runtime..."
mkdir -p /run/sshd
chmod 755 /run/sshd
echo 'd /run/sshd 0755 root root -' > /etc/tmpfiles.d/sshd.conf
systemd-tmpfiles --create || true

# prevent old manual sshd listener from blocking ports
pkill -f '/usr/sbin/sshd -D' 2>/dev/null || true
sleep 1

echo "🔐 Installing SSH stack..."
bash modules/ssh.sh




echo "🚀 Installing Trojan-Go..."
curl -L https://github.com/p4gefau1t/trojan-go/releases/latest/download/trojan-go-linux-amd64.zip -o /tmp/trojan-go.zip
cd /tmp
unzip -o trojan-go.zip
install -m 755 trojan-go /usr/local/bin/trojan-go
mkdir -p /etc/trojan-go

TROJANGO_DEFAULT_PASSWORD=$(openssl rand -hex 8)
cat > /etc/trojan-go/config.json <<TROJANGO_CONFIG
{
  "run_type": "server",
  "local_addr": "0.0.0.0",
  "local_port": 2087,
  "remote_addr": "www.cloudflare.com",
  "remote_port": 80,
  "password": ["${TROJANGO_DEFAULT_PASSWORD}"],
  "ssl": {
    "cert": "/etc/xray/ssl/fullchain.pem",
    "key": "/etc/xray/ssl/privkey.pem"
  }
}
TROJANGO_CONFIG


cat > /etc/systemd/system/trojan-go.service <<'TROJANGO_SERVICE'
[Unit]
Description=Trojan-Go Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/trojan-go -config /etc/trojan-go/config.json
Restart=always

[Install]
WantedBy=multi-user.target
TROJANGO_SERVICE

echo "🔎 Testing Trojan-Go config..."
timeout 3 /usr/local/bin/trojan-go -config /etc/trojan-go/config.json >/tmp/trojan-go-test.log 2>&1 || true
cat /tmp/trojan-go-test.log || true

systemctl daemon-reload
systemctl enable trojan-go
systemctl reset-failed trojan-go || true
systemctl restart trojan-go
systemctl is-active --quiet trojan-go || {
    echo "❌ Trojan-Go failed to start"
    journalctl -u trojan-go -n 80 --no-pager
    exit 1
}


echo "🚀 Enable services..."
systemctl daemon-reload
systemctl enable xray
mkdir -p /usr/local/etc/xray

python3 <<'PYX'
import re
from pathlib import Path

src = Path("/etc/xray/config.json")
dst = Path("/usr/local/etc/xray/config.json")

s = src.read_text()
s = re.sub(r'^\s*#.*$', '', s, flags=re.MULTILINE)
s = re.sub(r',\s*}', '}', s)
s = re.sub(r',\s*]', ']', s)

dst.write_text(s)
PYX

chmod 755 /usr/local/etc /usr/local/etc/xray
chmod 644 /usr/local/etc/xray/config.json
xray run -test -config /usr/local/etc/xray/config.json
systemctl restart xray
systemctl enable nginx
nginx -t
systemctl restart nginx

echo "🚀 Installing UDPGW..."

apt-get install -y git cmake make gcc g++ libssl-dev libnss3-dev libnspr4-dev

rm -rf /tmp/badvpn
git clone https://github.com/ambrop72/badvpn.git /tmp/badvpn
mkdir -p /tmp/badvpn/build
cd /tmp/badvpn/build
cmake .. -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_UDPGW=1
make -j$(nproc)
systemctl stop 'udpgw@*' 2>/dev/null || true
pkill -f badvpn-udpgw 2>/dev/null || true
sleep 1
rm -f /usr/bin/badvpn-udpgw
install -m 755 udpgw/badvpn-udpgw /usr/bin/badvpn-udpgw
cd /root/smilevpn-installer

cat > /etc/systemd/system/udpgw@.service <<'SERVICE'
[Unit]
Description=BadVPN UDPGW on port %i
After=network.target

[Service]
ExecStart=/usr/bin/badvpn-udpgw --listen-addr 0.0.0.0:%i --max-clients 1000
Restart=always

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload

for port in 7300 7301 7302
do
  systemctl enable udpgw@$port
  systemctl restart udpgw@$port
done

if command -v ufw >/dev/null 2>&1; then
    ufw allow 7300:7302/tcp || true
    ufw allow 7300:7302/udp || true
fi

echo "✅ UDPGW ACTIVE (7300-7302)"

echo "🚀 Installing UDP Custom..."
bash modules/udp-custom.sh
echo "✅ UDP Custom ACTIVE"

echo "🚀 Installing ZiVPN..."
bash modules/zivpn.sh
echo "✅ ZiVPN ACTIVE"

echo "SUCCESS" > "$SMILEVPN_STATUS_FILE"
echo "SMILEVPN_INSTALL_DONE"
echo "✅ SmileVPN installer DONE"
echo "DOMAIN=$DOMAIN"
echo "XRAY=ON"
echo "NGINX=ON"
echo "SSL=$SSL_MODE"
