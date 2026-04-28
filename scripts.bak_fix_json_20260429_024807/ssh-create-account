#!/bin/bash

USERNAME=$1
PASSWORD=$2
EXPIRED_AT=$3
IPLIMIT="5"

IP=$(curl -s ipv4.icanhazip.com)
ISP=$(cat /etc/xray/isp)
CITY=$(cat /etc/xray/city)
DOMAIN=$(cat /etc/xray/domain)

if [ ! -e /etc/xray/sshx ]; then
mkdir -p /etc/xray/sshx
fi
if [ ! -e /etc/xray/sshx/akun ]; then
mkdir -p /etc/xray/sshx/akun
fi
if [ -z ${IPLIMIT} ]; then
IPLIMIT="0"
fi
echo "${IPLIMIT}" >/etc/xray/sshx/${USERNAME}IP

useradd -e "${EXPIRED_AT}" -s /bin/false -M "${USERNAME}" &> /dev/null
echo -e "${PASSWORD}\n${PASSWORD}\n" | passwd "${USERNAME}" &> /dev/null
echo -e "### ${USERNAME} ${EXPIRED_AT} ${PASSWORD}" >> /etc/xray/ssh

cat > /var/www/html/ssh-$USERNAME.txt <<-END
=========================
   SmileVpn Tunneling 
=========================

Format SSH OVPN Account
=========================
Username         : $USERNAME
Password         : $PASSWORD
=========================
ISP              : $ISP
CITY             : $CITY
IP               : $IP
Host             : $DOMAIN
Port OpenSSH     : 443, 80, 22
Port Dropbear    : 443, 109
Port Dropbear WS : 443, 109
Port SSH UDP     : 1-65535
Port SSH WS      : 80, 8080, 8081-9999
Port SSH SSL WS  : 443
Port SSL/TLS     : 400-900
Port OVPN WS SSL : 443
Port OVPN SSL    : 443
Port OVPN TCP    : 1194
Port OVPN UDP    : 2200
BadVPN UDP       : 7100, 7300, 7300
=================================
Payload WSS: GET wss://BUG.COM/ HTTP/1.1[crlf]Host: $DOMAIN[crlf]Upgrade: websocket[crlf][crlf] 
=================================
Payload Enchanced: PATCH / HTTP/1.1[crlf]Host: [host][crlf]Host: bug.com[crlf]Upgrade: websocket[crlf]HTTP/ 3600[crlf]Sec-WebSocket-Extensions: superspeed[crlf]
=================================
SSH TLS/SNI : $DOMAIN:443@$USERNAME:$PASSWORD
SSH Non TLS : $DOMAIN:80@$USERNAME:$PASSWORD
=================================
OVPN Download : https://$DOMAIN:81/
=================================
Berakhir Pada    : $EXPIRED_AT
=================================

END

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a /etc/xray/sshx/akun/log-create-${USERNAME}.log
echo "            SSH Account" | tee -a /etc/xray/sshx/akun/log-create-${USERNAME}.log
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a /etc/xray/sshx/akun/log-create-${USERNAME}.log
echo "Username         : ${USERNAME}" | tee -a /etc/xray/sshx/akun/log-create-${USERNAME}.log
echo "Password         : ${PASSWORD}" | tee -a /etc/xray/sshx/akun/log-create-${USERNAME}.log
echo "Expired On       : ${EXPIRED_AT}" | tee -a /etc/xray/sshx/akun/log-create-${USERNAME}.log
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a /etc/xray/sshx/akun/log-create-${USERNAME}.log
echo "ISP              : ${ISP}" | tee -a /etc/xray/sshx/akun/log-create-${USERNAME}.log
echo "CITY             : ${CITY}" | tee -a /etc/xray/sshx/akun/log-create-${USERNAME}.log
echo "IP               : ${IP}" | tee -a /etc/xray/sshx/akun/log-create-${USERNAME}.log
echo "Host             : ${DOMAIN}" | tee -a /etc/xray/sshx/akun/log-create-${USERNAME}.log
echo "Limit Ip         : ${IPLIMIT} IP" | tee -a /etc/xray/sshx/akun/log-create-${USERNAME}.log
echo "Port OpenSSH     : 443, 80, 22" | tee -a /etc/xray/sshx/akun/log-create-${USERNAME}.log
echo "Port SSH UDP     : 1-65535" | tee -a /etc/xray/sshx/akun/log-create-${USERNAME}.log
echo "Port Dropbear    : 443, 109" | tee -a /etc/xray/sshx/akun/log-create-${USERNAME}.log
echo "Port SSH WS      : 80, 8080, 8081-9999" | tee -a /etc/xray/sshx/akun/log-create-${USERNAME}.log
echo "Port SSH SSL WS  : 443" | tee -a /etc/xray/sshx/akun/log-create-${USERNAME}.log
echo "Port SSL/TLS     : 400-900" | tee -a /etc/xray/sshx/akun/log-create-${USERNAME}.log
echo "Port OVPN WS SSL : 443" | tee -a /etc/xray/sshx/akun/log-create-${USERNAME}.log
echo "Port OVPN SSL    : 443" | tee -a /etc/xray/sshx/akun/log-create-${USERNAME}.log
echo "Port OVPN TCP    : 443, 1194" | tee -a /etc/xray/sshx/akun/log-create-${USERNAME}.log
echo "Port OVPN UDP    : 2200" | tee -a /etc/xray/sshx/akun/log-create-${USERNAME}.log
echo "BadVPN UDP       : 7100, 7300, 7300" | tee -a /etc/xray/sshx/akun/log-create-${USERNAME}.log
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a /etc/xray/sshx/akun/log-create-${USERNAME}.log
echo "OVPN Download    : https://$DOMAIN:81/" | tee -a /etc/xray/sshx/akun/log-create-${USERNAME}.log
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a /etc/xray/sshx/akun/log-create-${USERNAME}.log
echo "Http Custom Udp  : ${DOMAIN}:1-65535@${USERNAME}:${PASSWORD}" | tee -a /etc/xray/sshx/akun/log-create-${USERNAME}.log
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a /etc/xray/sshx/akun/log-create-${USERNAME}.log
echo "Save Link Account: https://$DOMAIN:81/ssh-$USERNAME.txt" | tee -a /etc/xray/sshx/akun/log-create-${USERNAME}.log
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a /etc/xray/sshx/akun/log-create-${USERNAME}.log
echo "Payload WSS" | tee -a /etc/xray/sshx/akun/log-create-${USERNAME}.log
echo "GET wss://isi_bug_disini HTTP/1.1[crlf]Host: ${DOMAIN}[crlf]Upgrade: websocket[crlf][crlf]" | tee -a /etc/xray/sshx/akun/log-create-${USERNAME}.log
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a /etc/xray/sshx/akun/log-create-${USERNAME}.log
echo "Payload WS" | tee -a /etc/xray/sshx/akun/log-create-${USERNAME}.log
echo "GET / HTTP/1.1[crlf]Host: ${DOMAIN}[crlf]Upgrade: websocket[crlf][crlf]" | tee -a /etc/xray/sshx/akun/log-create-${USERNAME}.log
