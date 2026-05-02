#!/bin/bash

USERNAME=$1
EXPIRED_AT=$2

EXP=$(grep -wE "^#vm ${USERNAME}" "/etc/xray/config.json" | cut -d ' ' -f 3 | sort | uniq)
sed -i "s/#vm ${USERNAME} ${EXP}/#vm ${USERNAME} ${EXPIRED_AT}/g" /etc/xray/config.json
sed -i "s/#vmg ${USERNAME} ${EXP}/#vmg ${USERNAME} ${EXPIRED_AT}/g" /etc/xray/config.json

systemctl restart xray > /dev/null 2>&1
