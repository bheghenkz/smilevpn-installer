#!/bin/bash
set -e

mkdir -p /etc/udp

install -m 755 "$(dirname "$0")/../bin/udp-custom" /etc/udp/udp-custom
cp "$(dirname "$0")/../config/udp-custom/config.json" /etc/udp/config.json
chmod +x /etc/udp/udp-custom
chmod 644 /etc/udp/config.json

cat > /etc/systemd/system/udp-custom.service <<'SERVICE'
[Unit]
Description=UDP Custom by ePro Dev. Team

[Service]
User=root
Type=simple
ExecStart=/etc/udp/udp-custom server -exclude server
WorkingDirectory=/etc/udp/
Restart=always
RestartSec=2s

[Install]
WantedBy=default.target
SERVICE

systemctl daemon-reload
systemctl enable udp-custom
systemctl restart udp-custom

ufw allow 1:65535/udp || true
iptables -I INPUT -p udp --dport 1:65535 -j ACCEPT || true

SERVICE_STATUS=$(systemctl is-active udp-custom || true)
echo "UDP Custom status: $SERVICE_STATUS"
