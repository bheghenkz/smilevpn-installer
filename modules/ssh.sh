#!/bin/bash

set -e

echo "🔐 Installing SSH stack..."

apt update -y
apt install -y openssh-server dropbear

echo "SmileVPN Server" > /etc/kyt.txt
echo "SmileVPN Server" > /etc/banner.txt

mkdir -p /etc/ssh
mkdir -p /etc/default
mkdir -p /etc/systemd/system

# Backup SSH config lama
if [ -f /etc/ssh/sshd_config ]; then
    cp /etc/ssh/sshd_config "/etc/ssh/sshd_config.bak.$(date +%s)"
fi

# Install SSH config baru
cp config/sshd_config /etc/ssh/sshd_config
chmod 600 /etc/ssh/sshd_config

# Install Dropbear config
cp config/dropbear.conf /etc/default/dropbear

# Install WebSocket SSH
systemctl stop ws 2>/dev/null || true
pkill -f '/usr/bin/ws' 2>/dev/null || true
sleep 1
rm -f /usr/bin/ws
install -m 755 bin/ws /usr/bin/ws
cp config/tun.conf /usr/bin/tun.conf
cp config/ws.service /etc/systemd/system/ws.service

chmod +x /usr/bin/ws
chmod 644 /usr/bin/tun.conf
chmod 644 /etc/systemd/system/ws.service

systemctl daemon-reload

# Enable/restart SSH, support Debian/Ubuntu service name
if systemctl list-unit-files | grep -q '^ssh.service'; then
    systemctl enable ssh
    systemctl restart ssh
elif systemctl list-unit-files | grep -q '^sshd.service'; then
    systemctl enable sshd
    systemctl restart sshd
else
    service ssh restart || service sshd restart || true
fi

systemctl enable dropbear
systemctl restart dropbear

systemctl enable ws
systemctl restart ws

cat >/etc/kyt.txt <<'EOF'
<p style="text-align:center"><b>
<br><font color='green'><b>╭═══════════════════════╮</b></font>
<br><font color='#8A95FF'><b>⇱ SmileVPN ⇲</b></font>
<br><font color='green'><b>╰═══════════════════════╯</b><br></font>
<br><font color='#FF000E'>&ensp;⇱ NO DDOS ⇲</font>
<br><font color='#3FFFAD'>&ensp;⇱ NO HACKING ⇲</font>
<br><font color='#52fc03'>&ensp;⇱ NO MULTILOGIN ⇲</font>
<br><font color='#0367fc'>&ensp;⇱ MELANGGAR AUTO BANNED ⇲</font>
<br><font color='green'><b>┏━━━━━━━━━━ ✫ ━━━━━━━━━━┓</b></font>
<br><font color='#8A95FF'><b>⇱ KONTAK ADMIN ⇲</b></font>
<br><font color='yellow'><b>Admin: t.me/fensmilebots</b></font>
<br><font color='green'><b>┗━━━━━━━━━━━━━━━━━━━━━━┛</b><br></font>
<br><font color='yellow'><b>Menyediakan kebutuhan tunneling, akun dan config premium, sewa vps, sewa dan reseller autoscript</b></font>
</b></p>
EOF

chmod 644 /etc/kyt.txt
groupadd -f smilevpn-users

sed -i '/^Banner \/etc\/kyt.txt/d' /etc/ssh/sshd_config
sed -i '/^Match Group smilevpn-users/,$d' /etc/ssh/sshd_config

cat >> /etc/ssh/sshd_config <<'EOF'

Match Group smilevpn-users
    Banner /etc/kyt.txt
EOF

echo "✅ SSH stack installed"
