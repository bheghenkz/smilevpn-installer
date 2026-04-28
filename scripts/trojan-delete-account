#!/bin/bash

USERNAME=$1
EXPIRED_AT=$2


sed -i "/^#tr ${USERNAME} ${EXPIRED_AT}/,/^},{/d" /etc/xray/config.json
sed -i "/^#trg ${USERNAME} ${EXPIRED_AT}/,/^},{/d" /etc/xray/config.json

rm /etc/trojan/${USERNAME}IP >/dev/null 2>&1
rm /etc/trojan/$USERNAME
rm /var/www/html/trojan-$USERNAME.txt
rm /etc/trojan/akun/log-create-${USERNAME}.log
rm /etc/limit/trojan/${USERNAME}
systemctl restart xray > /dev/null 2>&1
