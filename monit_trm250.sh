
cd /root

ifconfig wwan0 >> /var/log/screen_monit.log

screen -S ModemQuec -X kill
screen -Logfile /var/log/screen_monit.log -dmS ModemQuec -L /dev/ttyUSB2 
screen -S ModemQuec -X stuff "ATI\r"
sleep 0.3
screen -S ModemQuec -X stuff "AT&V\r"
sleep 0.3
screen -S ModemQuec -X stuff 'AT+CGPADDR\r'
sleep 0.3
screen -S ModemQuec -X stuff 'AT+QCFG="nwscanseq"\r'
sleep 0.3

screen -S ModemQuec -X stuff 'AT+CSQ\r'
sleep 0.3
screen -S ModemQuec -X stuff 'AT+COPS?\r'
sleep 0.3
screen -S ModemQuec -X stuff 'AT+CGDCONT?\r'
sleep 0.3
screen -S ModemQuec -X stuff 'AT+QCFG="BAND"\r'
sleep 0.3
screen -S ModemQuec -X stuff 'AT+QNWINFO\r'
sleep 0.3
sleep 10
( set -o pipefail; ifconfig | grep -i wwan0 ); if [[ "$?" -eq "0" ]]; then echo success; else pm2 restart quectel-CM ; fi
counter=1
while [ $counter -le 600 ]
do
date >> /var/log/screen_monit.log
# screen -Logfile /var/log/screen_monit.log -dmS ModemQuec -L /dev/ttyUSB2 
ping -i 1 -I wwan0 1.1.1.111 -c 1 -O >> /var/log/screen_monit.log
ifconfig wwan0 | grep -i bytes >> /var/log/screen_monit.log
screen -S ModemQuec -X stuff 'AT+CSQ\r'
sleep 0.3
screen -S ModemQuec -X stuff 'AT+COPS?\r'
sleep 0.3
screen -S ModemQuec -X stuff 'AT+QNWINFO\r'
sleep 0.3
screen -S ModemQuec -X stuff 'AT+QENG="servingcell"\r'
curl http://ipinfo.io/json --connect-timeout 2 | grep \"ip\" > /etc/issue.d/publicIP.issue
cat /etc/issue.d/publicIP.issue >> /var/log/screen_monit.log 
# curl http://ipinfo.io/json --connect-timeout 2 | grep \"ip\" >> /var/log/screen_monit.log 
sleep 10
( set -o pipefail; ifconfig | grep -i wwan0 ); if [[ "$?" -eq "0" ]]; then echo success; else pm2 restart quectel-CM ; fi

((counter++))
done

screen -S ModemQuec -X stuff 'AT+QENG="servingcell"\r'
sleep 0.3


screen -S ModemQuec -X kill

pm2 restart monit_trm250

# cat screenlog.0

