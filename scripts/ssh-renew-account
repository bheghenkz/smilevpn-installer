#!/bin/bash

USERNAME=$1
EXPIRED_AT=$2

EXP=$(grep -wE "^### ${USERNAME}" "/etc/xray/ssh" | cut -d ' ' -f 3 | sort | uniq)
usermod -e "${EXPIRED_AT}" "${USERNAME}" &> /dev/null
sed -i "s/### ${USERNAME} ${EXP}/### ${USERNAME} ${EXPIRED_AT}/g" /etc/xray/ssh >/dev/null