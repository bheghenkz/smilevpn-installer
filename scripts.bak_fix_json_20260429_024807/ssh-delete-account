#!/bin/bash

USERNAME=$1


exp=$(grep -wE "^### ${USERNAME}" "/etc/xray/ssh" | cut -d ' ' -f 3 | sort | uniq)
pass=$(grep -wE "^### ${USERNAME}" "/etc/xray/ssh" | cut -d ' ' -f 4 | sort | uniq)
userdel "${USERNAME}" &> /dev/null
sed -i "s/### ${USERNAME} ${exp} ${pass}//g" /etc/xray/ssh 

rm /var/www/html/ssh-$USERNAME.txt >/dev/null 2>&1
rm /etc/xray/sshx/${USERNAME}IP >/dev/null 2>&1
rm /etc/xray/sshx/${USERNAME}login >/dev/null 2>&1
rm /etc/xray/sshx/akun/log-create-${USERNAME}.log