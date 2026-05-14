#!/bin/bash

echo "Installing ZiVPN..."

systemctl stop zivpn 2>/dev/null
systemctl stop zivpn-api 2>/dev/null

mkdir -p /etc/zivpn

cp /root/smilevpn-installer/zivpn-assets/zivpn /usr/local/bin/zivpn
chmod +x /usr/local/bin/zivpn

tar -xzvf /root/smilevpn-installer/zivpn-assets/zivpn-config.tar.gz -C /

cp /root/smilevpn-installer/zivpn-assets/zivpn.service /etc/systemd/system/
cp /root/smilevpn-installer/zivpn-assets/zivpn-api.service /etc/systemd/system/

iptables -t nat -C PREROUTING -i eth0 -p udp --dport 6000:19999 -j DNAT --to-destination :5667 2>/dev/null || \
iptables -t nat -A PREROUTING -i eth0 -p udp --dport 6000:19999 -j DNAT --to-destination :5667

systemctl daemon-reload
systemctl enable zivpn
systemctl enable zivpn-api

systemctl restart zivpn
systemctl restart zivpn-api

echo "ZiVPN Installed Successfully"
