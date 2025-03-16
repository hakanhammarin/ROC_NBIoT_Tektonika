cd /root
lsusb -t >> /var/log/init_trm250.log

 qmicli --device=/dev/cdc-wdm0 --device-open-proxy --dms-get-manufacturer >> /var/log/init_trm250.log
# qmicli --device=/dev/cdc-wdm0 --device-open-proxy --wds-start-network="ip-type=4,apn=iot.1nce.net" --client-no-release-cid

# udhcpc -q -f -n -i wwan0

ifconfig wwan0 >> /var/log/init_trm250.log

screen -S ModemQuec -X kill
# rm screenlog.0
screen -dmS ModemQuec -L /dev/ttyUSB2
screen -S ModemQuec -X stuff "ATI\r"
sleep 0.3
screen -S ModemQuec -X stuff 'AT+QCFG="nb1/bandprior",08\r'
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
screen -S ModemQuec -X stuff 'AT+QCFG="BAND",0,80,80\r'
screen -S ModemQuec -X stuff 'AT+QCFG="BAND"\r'

sleep 0.3
screen -S ModemQuec -X stuff 'AT+QCFG="iotopmode",1\r'
sleep 0.3
screen -S ModemQuec -X stuff 'AT+QCFG="nwscanseq",030201\r'
screen -S ModemQuec -X stuff 'AT+QCFG="nwscanseq"\r'

sleep 0.3
screen -S ModemQuec -X stuff 'AT+QCFG="nwscanmode",3\r'
sleep 0.3
screen -S ModemQuec -X stuff 'AT+QCFG="nwscanmode"\r'

screen -S ModemQuec -X stuff 'AT+QCFG="BAND"\r'
sleep 0.3
screen -S ModemQuec -X stuff 'AT+QNWINFO\r'
sleep 0.3
screen -S ModemQuec -X stuff 'AT+QCOPS=2,1\r'
sleep 1
screen -S ModemQuec -X stuff 'AT+QCOPS=4,1\r'
sleep 1
screen -S ModemQuec -X stuff 'AT+QENG="servingcell"\r'
sleep 0.3
# screen -S ModemQuec -X stuff "AT&W\r"
# sleep 0.3
screen -S ModemQuec -X kill >> /var/log/init_trm250.log


qmicli --device=/dev/cdc-wdm0 --device-open-proxy --dms-get-manufacturer >> /var/log/init_trm250.log
qmicli --device=/dev/cdc-wdm0 --device-open-proxy --wds-start-network="ip-type=4,apn=iot.1nce.net" --client-no-release-cid >> /var/log/init_trm250.log

udhcpc -q -f -n -i wwan0 >> /var/log/init_trm250.log

ifconfig wwan0 >> /var/log/init_trm250.log


traceroute -Un 1.1.1.111 -i wwan0 -m 10 -q 1 >> /var/log/init_trm250.log
# ping -c 5 -I wwan0 1.1.1.1
ping -i 10 -I wwan0 1.1.1.111 -c 5 -O >> /var/log/init_trm250.log

# /root/monit_trm250.sh &
