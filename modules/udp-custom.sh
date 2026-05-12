#!/bin/bash
set -e
mkdir -p /root/udp
install -m 755 $(dirname $0)/../bin/udp-custom /usr/local/bin/udp-custom
cp $(dirname $0)/../config/udp-custom/config.json /root/udp/config.json
cat > /etc/systemd/system/udp-custom.service <<'SERVICE'
[Unit]
Description=UDP Custom
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/udp-custom server
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
SERVICE
systemctl daemon-reload
systemctl enable udp-custom
systemctl restart udp-custom
ufw allow 1:65535/udp || true
iptables -I INPUT -p udp --dport 1:65535 -j ACCEPT || true
SERVICE_STATUS=$(systemctl is-active udp-custom || true)
echo "UDP Custom status: $SERVICE_STATUS"
