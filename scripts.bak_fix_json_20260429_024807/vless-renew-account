#!/bin/bash

USERNAME=$1
EXPIRED_AT=$2

EXP=$(grep -wE "^#vl ${USERNAME}" "/etc/xray/config.json" | cut -d ' ' -f 3 | sort | uniq)
sed -i "s/#vl ${USERNAME} ${EXP}/#vl ${USERNAME} ${EXPIRED_AT}/g" /etc/xray/config.json
sed -i "s/#vlg ${USERNAME} ${EXPIRED_AT}/#vlg ${USERNAME} ${EXPIRED_AT}/g" /etc/xray/config.json

systemctl restart xray > /dev/null 2>&1
