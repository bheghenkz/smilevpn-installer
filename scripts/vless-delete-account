#!/bin/bash

USERNAME=$1
EXPIRED_AT=$2

sed -i "/^#vl ${USERNAME} ${EXPIRED_AT}/,/^},{/d" /etc/xray/config.json
sed -i "/^#vlg ${USERNAME} ${EXPIRED_AT}/,/^},{/d" /etc/xray/config.json

rm /etc/vless/${USERNAME}IP >/dev/null 2>&1
rm /var/www/html/vless-${USERNAME}.txt >/dev/null 2>&1
rm /etc/vless/akun/log-create-${USERNAME}.log
rm /etc/limit/vless/${USERNAME}
systemctl restart xray > /dev/null 2>&1
