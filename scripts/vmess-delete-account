#!/bin/bash

USERNAME=$1
EXPIRED_AT=$2

sed -i "/^#vmg ${USERNAME} ${EXPIRED_AT}/,/^},{/d" /etc/xray/config.json
sed -i "/^#vm ${USERNAME} ${EXPIRED_AT}/,/^},{/d" /etc/xray/config.json

rm /etc/vmess/${USERNAME}IP >/dev/null 2>&1
rm /var/www/html/vmess-$USERNAME.txt
rm /etc/limit/vmess/${USERNAME}
systemctl restart xray > /dev/null 2>&1