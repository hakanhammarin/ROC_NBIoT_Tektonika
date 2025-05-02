cd /root
# lsusb -t >> /var/log/init_trm250.log

# qmicli --device=/dev/cdc-wdm0 --device-open-proxy --dms-get-manufacturer >> /var/log/init_trm250.log
# qmicli --device=/dev/cdc-wdm0 --device-open-proxy --wds-start-network="ip-type=4,apn=iot.1nce.net" --client-no-release-cid

# udhcpc -q -f -n -i wwan0
date >> /var/log/init_trm250.log
pm2 stop quectel-CM
pm2 stop monit_trm250
screen -S ModemQuec -X kill
ifconfig wwan0 >> /var/log/init_trm250.log

screen -S ModemQuecInit -X kill
screen -ls | grep Detached | cut -d. -f1 | awk '{print $1}' | xargs -r kill
# rm screenlog.0
rm -f /root/screenlog.0 

screen -dmS ModemQuecInit -L /dev/ttyUSB2 -Logfile /var/log/screen_init.log
screen -S ModemQuecInit -X stuff "ATI\r"
sleep 0.3
# disconnect
screen -S ModemQuecInit -X stuff 'AT+COPS=2\r'
sleep 0.3
screen -S ModemQuecInit -X stuff "AT&F\r"
sleep 0.3
screen -S ModemQuecInit -X stuff "AT+CFUN=0\r"
sleep 0.3
screen -S ModemQuecInit -X stuff 'AT+QCFG="nb1/bandprior",08\r'
sleep 0.3
screen -S ModemQuecInit -X stuff 'AT+CGPADDR\r'
sleep 0.3
screen -S ModemQuecInit -X stuff 'AT+QCFG="nwscanseq"\r'
sleep 0.3
screen -S ModemQuecInit -X stuff 'AT+CSQ\r'
sleep 0.3
screen -S ModemQuecInit -X stuff 'AT+COPS?\r'
sleep 0.3
screen -S ModemQuecInit -X stuff 'AT+CGDCONT?\r'
sleep 0.3
screen -S ModemQuecInit -X stuff 'AT+QCFG="BAND",0,85,80,1\r'
sleep 1
screen -S ModemQuecInit -X stuff 'AT+QCFG="BAND"\r'
sleep 0.3
screen -S ModemQuecInit -X stuff 'AT+QCFG="iotopmode",1,1\r'
sleep 0.3
screen -S ModemQuecInit -X stuff 'AT+QCFG="nwscanseq",030201,1\r'
sleep 0.3
screen -S ModemQuecInit -X stuff 'AT+QCFG="nwscanseq"\r'
sleep 0.3
screen -S ModemQuecInit -X stuff 'AT+QCFG="nwscanmode",3,1\r'
sleep 0.3
screen -S ModemQuecInit -X stuff 'AT+QCFG="nwscanmode"\r'
sleep 0.3
screen -S ModemQuecInit -X stuff 'AT+QCFG="iotopmode",1,1\r'
sleep 0.3
screen -S ModemQuecInit -X stuff 'AT+QCFG="iotopmode"\r'
sleep 0.3
screen -S ModemQuecInit -X stuff 'AT+QNWINFO\r'
sleep 0.3
# screen -S ModemQuec -X stuff 'AT+QCOPS=2,1\r'
# sleep 1
# screen -S ModemQuec -X stuff 'AT+QCOPS=4,1\r'
# sleep 1
screen -S ModemQuecInit -X stuff 'AT+QENG="servingcell"\r'
sleep 0.3


screen -S ModemQuecInit -X kill >> /var/log/init_trm250.log
screen -ls | grep Detached | cut -d. -f1 | awk '{print $1}' | xargs -r kill

uhubctl -a off -l 2 
sleep 2
uhubctl -a on -l 2 
sleep 5

screen -dmS ModemQuecInit -L /dev/ttyUSB2 -Logfile /var/log/screen_init.log

count_searching=0
while [ $count_searching -eq 0 ]
do
screen -S ModemQuecInit -X stuff 'AT+QENG="servingcell"\r'
sleep 5
tail -n 4 /root/screenlog.0 | grep -i servingcell
tail -n 4 /root/screenlog.0 
count_searching=$(tail -n 4 /root/screenlog.0  | grep -ic servingcell)
echo "$count_searching"
if [[ "$count_searching" -eq 0 ]]; then
    echo "Wait for init"
else
    echo "Start SEARCHING"
fi

done

screen -S ModemQuecInit -X kill >> /var/log/init_trm250.log
screen -ls | grep Detached | cut -d. -f1 | awk '{print $1}' | xargs -r kill
screen -dmS ModemQuecInit -L /dev/ttyUSB2 -Logfile /var/log/screen_init.log

count_searching=1
while [ $count_searching -ge 1 ]
do
screen -S ModemQuecInit -X stuff 'AT+QENG="servingcell"\r'
sleep 10
tail -n 4 /root/screenlog.0 | grep -i servingcell
tail -n 4 /root/screenlog.0 
count_searching=$(tail -n 4 /root/screenlog.0  | grep -ic SEARCH)
echo "$count_searching"
if [[ "$count_searching" -ge 1 ]]; then
    echo "SEARCHING"
else
    echo "Found Operator"
fi

done

count_operator=0
while [ $count_operator -eq 0 ]
do
screen -S ModemQuecInit -X stuff 'AT+COPS=?\r'
sleep 10
tail -n 4 /root/screenlog.0 | grep -i COPS
tail -n 4 /root/screenlog.0 

count_operator=$(tail -n 4 /root/screenlog.0 | grep -ic 24007)
echo "$count_operator"
if [[ "$count_operator" -ge 1 ]]; then
    echo "Found operator - success"
else
    echo "No operator - fail"
fi

done
screen -S ModemQuecInit -X stuff 'AT+QENG="servingcell"\r'

tail -n 10 /root/screenlog.0 
# select Tele2
screen -S ModemQuecInit -X stuff 'AT+COPS=4,2,24007,9\r'
# select Telia
# screen -S ModemQuecInit -X stuff 'AT+COPS=1,2,24001,8\r'
# select Telenor
# screen -S ModemQuecInit -X stuff 'AT+COPS=4,2,24008,9\r'
sleep 0.3
screen -S ModemQuecInit -X stuff "AT+CFUN=1\r"
sleep 0.3
# screen -S ModemQuec -X stuff "AT&W\r"
# sleep 0.3


screen -S ModemQuecInit -X stuff 'AT+QENG="servingcell"\r'

screen -S ModemQuecInit -X kill >> /var/log/init_trm250.log
screen -ls | grep Detached | cut -d. -f1 | awk '{print $1}' | xargs -r kill
cat /root/screenlog.0 
# qmicli --device=/dev/cdc-wdm0 --device-open-proxy --dms-get-manufacturer >> /var/log/init_trm250.log
# qmicli --device=/dev/cdc-wdm0 --device-open-proxy --wds-start-network="ip-type=4,apn=iot.1nce.net" --client-no-release-cid >> /var/log/init_trm250.log

# udhcpc -q -f -n -i wwan0 >> /var/log/init_trm250.log

# ifconfig wwan0 >> /var/log/init_trm250.log


# traceroute -Un 1.1.1.111 -i wwan0 -m 10 -q 1 >> /var/log/init_trm250.log
# ping -c 5 -I wwan0 1.1.1.1
# ping -i 10 -I wwan0 1.1.1.111 -c 5 -O >> /var/log/init_trm250.log

# /root/monit_trm250.sh &
date >> /var/log/quectel-CM.log
# /usr/local/bin/quectel-CM -f /var/log/quectel-CM.log
echo ENDED INIT  >> /var/log/quectel-CM.log
date >> /var/log/init_trm250.log
date >> /var/log/quectel-CM.log
# pm2 start quectel-CM
read -p "Press [Enter] to continue..."
reboot
