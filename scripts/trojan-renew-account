#!/bin/bash

USERNAME=$1
EXPIRED_AT=$2

EXP=$(grep -wE "^#trg ${USERNAME}" "/etc/xray/config.json" | cut -d ' ' -f 3 | sort | uniq)
sed -i "s/#tr ${USERNAME} ${EXP}/#tr ${USERNAME} ${EXPIRED_AT}/g" /etc/xray/config.json
sed -i "s/#trg ${USERNAME} ${EXP}/#trg ${USERNAME} ${EXPIRED_AT}/g" /etc/xray/config.json

systemctl restart xray > /dev/null 2>&1
