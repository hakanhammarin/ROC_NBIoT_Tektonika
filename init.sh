#!/bin/bash
# Script created by Oskar Berg 2012-

# ROC Functions

# FunctionId    FunctionName                    SortOrder
# 1             online_control                  1
# 2             online_control_sirap_ola_meos   2
# 8             online_control_si_raw_com       7
# 9             online_control_si_raw_tcp       5
# 10            online_control_si_raw_udp       6
# 12            online_control_sirap_roc_v1     4
# 15            ola_card_readout                15

# PunchingSystem
# SportIdent
# EmitRS232
# EmitECU

# source /home/pi/shared.sh

function ExecuteNewSettings {

   # Function changed

   new_ROCFunction=$(grep "^FunctionId" /home/pi/roc.ini | cut -c12- | tr -d "\n\r")
   if [ "a$new_ROCFunction" != "a$ROCFunction" ]; then
      if [ -z "$new_ROCFunction" ]; then
         SendMessage "init.sh" "New FunctionId that was ordered is empty. Not doing anything!" "1" "/home/pi/10/init.log"
      else
         SendMessage "init.sh" "Got order to change function for ROC. Had function id $ROCFunction and changing to function id $new_ROCFunction. Rebooting..." "0" "/home/pi/10/init.log"
         reboot="Y"
         reboottext="Got order to change function for ROC. Had function id $ROCFunction and changing to function id $new_ROCFunction."
      fi
   fi

# Punchingsystem

   punchingsystem=$(grep "^PunchingSystem" /home/pi/roc.ini | cut -c16- | tr -d "\n\r")
   if [ "a$punchingsystem" = "a" ]; then
      punchingsystem="SportIdent"
   fi
   if [ "a$old_PunchingSystem" != "a$punchingsystem" ]; then
      SendMessage "init.sh" "New punching system choosen. Old punching system is $old_PunchingSystem and we change to $punchingsystem. Rebooting..." "1" "/home/pi/10/init.log"
      reboot="Y"
   fi


# Wifi
   new_WiFi=$(grep "^WiFiNetwork" /home/pi/roc.ini | base64 --wrap=0)
   old_WiFi=$(</home/pi/wifi.ini)
   if [ "a$new_WiFi" != "a$old_WiFi" ]; then
      echo New WiFi-settings. Changing settings. >> /home/pi/10/init.log
#      echo $new_WiFi | base64 --wrap=0 > /home/pi/wifi.ini
      grep "^WiFiNetwork" /home/pi/roc.ini | base64 --wrap=0 > /home/pi/wifi.ini
      echo ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev > /etc/wpa_supplicant/wpa_supplicant.conf
      echo update_config=1 >> /etc/wpa_supplicant/wpa_supplicant.conf

      for line in $(grep "^WiFiNetwork=" /home/pi/roc.ini); do
         wifi=$(echo $line | cut -c15-)
         wifikey=$(grep "^WiFiNetworkKey=$(echo $line | cut -c13- | cut --delimiter=- --fields=1)-" /home/pi/roc.ini | cut -c18-)
         echo $wifi-$wifikey
         echo >> /etc/wpa_supplicant/wpa_supplicant.conf
         wpa_passphrase "$wifi" "$wifikey" >> /etc/wpa_supplicant/wpa_supplicant.conf
      done
#      wpa_cli -i wlan0 reconfigure
#      systemctl daemon-reload
#      systemctl restart dhcpcd
      reboot="Y"
      reboottext="SSID or password is changed."
   fi

# Network settings
      ClusterPunch=$(grep "^ClusterPunch" /home/pi/roc.ini)
      ClusterPunch=${ClusterPunch:13}
      if [ "$ClusterPunch" = "Y" ]; then
         echo Punch cluster enabled. Checking network settings for eth0. | tee -a /home/pi/10/init.log
         changedconfig=false
         ClusterIP=$(grep "^ClusterIP" /home/pi/roc.ini)
         ClusterIP=${ClusterIP:10}
         if ((grep "^static routers=" /etc/dhcpcd.conf | grep -q "eth0") || (grep "^static domain_name_servers=" /etc/dhcpcd.conf | grep -q "eth0")); then
#         if ((grep -q "^static routers=" /etc/dhcpcd.conf) || (grep -q "^static domain_name_servers=" /etc/dhcpcd.conf)); then
            changedconfig=true
            echo ...Removing static IP settings. | tee -a /home/pi/10/init.log
         fi
         if (! ((grep -q "^interface eth0$" /etc/dhcpcd.conf) && (grep -q "^static ip_address=$ClusterIP/24     #eth0$" /etc/dhcpcd.conf))); then
            echo Wrong IP-address set on eth0. Changing it.
            changedconfig=true
         fi
         if $changedconfig; then
            echo ...Changing network config for cluster on eth0. | tee -a /home/pi/10/init.log
            sed -i "/eth0/d" /etc/dhcpcd.conf
#            sed -i '/interface eth0/d' /etc/dhcpcd.conf
#            sed -i '/static ip_address=/d' /etc/dhcpcd.conf
#            sed -i '/static routers=/d' /etc/dhcpcd.conf
#            sed -i '/static domain_name_servers=/d' /etc/dhcpcd.conf
            sed -i "/Static IP configuration:/a static ip_address=$ClusterIP/24     #eth0" /etc/dhcpcd.conf
            sed -i "/Static IP configuration:/a interface eth0" /etc/dhcpcd.conf
            SendMessage "init.sh" "ClusterPunch ordered. Changing IP address and rebooting...." "0" "/home/pi/10/init.log"
            if (( $restarts < 5 )); then
               killall monitor.sh minicallhome.sh
               reboot
               exit 1
            else
               echo Aborting reboot because of too many reboots without a complete reboot in between! >> /home/pi/10/init.log
            fi
         else
            SendMessage "init.sh" "ClusterPunch ordered. Correct IP address already set. Continuing." "0" "/home/pi/10/init.log"
         fi
         if (! ps aux | grep clusterpunch.sh | grep -v grep &>/dev/null); then
            echo Activating script for punching cluster syncing! | tee -a /home/pi/10/init.log
            nohup /home/pi/clusterpunch.sh &> /home/pi/10/clusterpunch.log &
         fi
      else
            # Remove punches for Cluster because cluster is not used...
         rm -f /home/pi/punches/out/*
         rm -f /home/pi/punches/remotein/*
         if (ps aux | grep clusterpunch.sh | grep -v grep); then
            killall clusterpunch.sh &>/dev/null
         fi

         tempvar=$(grep "^IPStatic" /home/pi/roc.ini)
         tempvar=${tempvar:9}
         if [ "$tempvar" = "Y" ]; then
            new_IPDNS=$(grep "^IPDNS" /home/pi/roc.ini)
            new_IPDNS=${new_IPDNS:6}
            new_IPGateway=$(grep "^IPGateway" /home/pi/roc.ini)
            new_IPGateway=${new_IPGateway:10}
            new_IPNetmask=$(grep "^IPNetmask" /home/pi/roc.ini)
            new_IPNetmask=${new_IPNetmask:10}
            new_IPAddress=$(grep "^IPAddress" /home/pi/roc.ini)
            new_IPAddress=${new_IPAddress:10}
            c=0
            x=0$( printf '%o' ${new_IPNetmask//./ } )
            while [ $x -gt 0 ]; do
               let c+=$((x%2)) 'x>>=1'
            done
            cidr="/$c"

            if (! ((grep -q "^interface eth0$" /etc/dhcpcd.conf) && (grep -q "^static ip_address=$new_IPAddress$cidr     #eth0$" /etc/dhcpcd.conf) && (grep -q "^static routers=$new_IPGateway     #eth0$" /etc/dhcpcd.conf) && (grep -q "^static domain_name_servers=$new_IPDNS     #eth0$" /etc/dhcpcd.conf))); then

               SendMessage "init.sh" "Changing IP-address to static..." "0" "/home/pi/10/init.log"

               sed -i "/eth0/d" /etc/dhcpcd.conf
#               sed -i '/interface eth0/d' /etc/dhcpcd.conf
#               sed -i '/static ip_address=/d' /etc/dhcpcd.conf
#               sed -i '/static routers=/d' /etc/dhcpcd.conf
#               sed -i '/static domain_name_servers=/d' /etc/dhcpcd.conf

               sed -i "/Static IP configuration:/a static domain_name_servers=$new_IPDNS     #eth0" /etc/dhcpcd.conf
               sed -i "/Static IP configuration:/a static routers=$new_IPGateway     #eth0" /etc/dhcpcd.conf
               sed -i "/Static IP configuration:/a static ip_address=$new_IPAddress$cidr     #eth0" /etc/dhcpcd.conf
               sed -i "/Static IP configuration:/a interface eth0" /etc/dhcpcd.conf

               echo Changed IP-address to static, rebooting... | tee -a /home/pi/10/init.log
               sync
               if (( $restarts < 5 )); then
                  killall monitor.sh minicallhome.sh
                  reboot
                  exit 1
               else
                  SendMessage "init.sh" "Aborting reboot because of too many reboots without a complete reboot in between!" "0" "/home/pi/10/init.log"
               fi
            fi
         else
#            if (grep -q 'interface eth0\|static ip_address\|static routers\|static domain_name_servers' /etc/dhcpcd.conf); then
            if (grep -q 'eth0' /etc/dhcpcd.conf); then
               echo Changing IP-address to dynamic, DHCP... | tee -a /home/pi/10/init.log
               SendMessage "init.sh" "Changing IP-address to dynamic, DHCP..." "0" "/home/pi/10/init.log"
               sed -i "/eth0/d" /etc/dhcpcd.conf
#               sed -i '/interface eth0/d' /etc/dhcpcd.conf
#               sed -i '/static ip_address=/d' /etc/dhcpcd.conf
#               sed -i '/static routers=/d' /etc/dhcpcd.conf
#               sed -i '/static domain_name_servers=/d' /etc/dhcpcd.conf
               echo Changed to dynamic IP-address, DHCP, rebooting... | tee -a /home/pi/10/init.log
               sync
               if (( $restarts < 5 )); then
                  killall monitor.sh minicallhome.sh
                  reboot
                  exit 1
               else
                  echo Aborting reboot because of too many reboots without a complete reboot in between! >> /home/pi/10/init.log
               fi
# Static IP configuration:
#interface eth0
#static ip_address=192.168.0.10/24
#static routers=192.168.0.1
#static domain_name_servers=192.168.0.1 8.8.8.8

            fi
         fi
      fi


      if [ "$reboot" = "Y" ]; then
         echo Rebooting... Reason is: $reboottext >> /home/pi/10/init.log
         echo Rebooting... Reason is: $reboottext
         sync
         if (( $restarts < 5 )); then
            killall monitor.sh minicallhome.sh
            reboot
            exit
         else
            echo Aborting reboot because of too many reboots without a complete reboot in between! >> /home/pi/10/init.log
            echo Aborting reboot because of too many reboots without a complete reboot in between!
         fi
      fi

   IoT="Y"
   UseMQTT=$(grep "^UseMQTT=" /home/pi/roc.ini | cut -c9- | tr -d "\n\r")
   if [ "$UseMQTT" = "Y" ]; then
      echo Using MQTT as transport instead of HTTPS. >> /home/pi/10/init.log
      IoT="Y"
   fi

}

function GetSetting {
   if (grep -q "^$1=" /home/pi/ROC_settings.ini); then
      echo "# Local setting" >> /home/pi/roc.ini
      echo $(grep ^$1= /home/pi/ROC_settings.ini) >> /home/pi/roc.ini
   else
      grep "^$1=" /home/pi/updateroc.txt >> /home/pi/roc.ini
   fi
}

function GetAllSettings {
   echo "### ROC settings from webservice and /boot/ROC/ROC_settings.ini" > /home/pi/roc.ini

   tr -d '\r' < /boot/ROC/ROC_settings.ini > /home/pi/ROC_settings.ini

   grep "UpdateROC" /home/pi/updateroc.txt >> /home/pi/roc.ini
   grep "NewComputerName" /home/pi/updateroc.txt >> /home/pi/roc.ini

# Get values if set
   GetSetting FunctionId
   GetSetting FunctionName
   GetSetting SSHUPnP
   GetSetting ModemAPN
   GetSetting APN_User
   GetSetting APN_Pass
   GetSetting ModemPIN
#   GetSetting SSIDName
   GetSetting WiFiNetwork
   GetSetting WiFiNetworkKey
   GetSetting WiFiRegDomain
   GetSetting PunchingSystem
   GetSetting ClusterPunch
   GetSetting ClusterIP
   GetSetting ClusterFriendIP
   GetSetting EMITcode
   GetSetting EmitPunchServer
   GetSetting EmitSendPunchesToEmitServer
   GetSetting URLtoCall
   GetSetting SIRAP
   GetSetting SIRAPSystem
   GetSetting SIRAPServerIP
   GetSetting SIRAPServerPort
   GetSetting SIRAPMiniCallHome
   GetSetting SIRAPCOMPortSpeed
   GetSetting ScreenShowInfo
   GetSetting sdtv_mode
   GetSetting sdtv_aspect
   GetSetting framebuffer_width
   GetSetting framebuffer_height
   GetSetting overscan_left
   GetSetting overscan_right
   GetSetting overscan_top
   GetSetting overscan_bottom
   GetSetting enable_gpio_serial
   GetSetting Simplex
   GetSetting Force4800
   GetSetting removePunchesROC
   GetSetting MiniCallHomeInterval
   GetSetting IPStatic
   GetSetting IPAddress
   GetSetting IPNetmask
   GetSetting IPGateway
   GetSetting IPDNS
   GetSetting Diploma
   GetSetting DiplomaMySQLServerIP
   GetSetting DiplomaMySQLServerPort
   GetSetting DiplomaMySQLUsername
   GetSetting DiplomaMySQLPassword
   GetSetting DiplomaDatabase
   GetSetting DiplomaCommandLine
   GetSetting DiplomaDontSendPunches
   GetSetting DiplomaImageUploadCounter
   GetSetting DiplomaImageViewer
   GetSetting res_Function
   GetSetting DiplomaMaster
   GetSetting KvarISkogen
   GetSetting PreWarningRelay
   GetSetting PreWarningRelayFontSize
   GetSetting PreWarningRelayFlipScreen
   GetSetting PreWarningRelayNumberOfRows
   GetSetting PreWarningRelayCodes
   GetSetting PreWarningRelaySound
   GetSetting PreWarningRelaySoundLanguage
   GetSetting PreWarningRelaySystem
   GetSetting PreWarningRelayUnitIds
   GetSetting DatabaseServerIP
   GetSetting DatabaseServerPort
   GetSetting DatabaseUser
   GetSetting DatabasePassword
   GetSetting DatabaseName
   GetSetting EventRaceId
   GetSetting ROCmasterPasswd
   GetSetting SendDirectSIRAP
   GetSetting SendDirectTCP
   GetSetting SendDirectSIRAPServerIP
   GetSetting SendDirectTCPServerIP
   GetSetting SendDirectSIRAPServerPort
   GetSetting SendDirectTCPServerPort
   GetSetting BackupRoute
   GetSetting SendDirectRadiocraft
   GetSetting RadiocraftPacketMode
   GetSetting VPNServer
   GetSetting VPNId
   GetSetting VPNName
   GetSetting VPNPort
   GetSetting PlayTuneAndDiod
   if (!(grep PlayTuneAndDiod /home/pi/roc.ini &> /dev/null)); then
      echo "PlayTuneAndDiod=Y" >> /home/pi/roc.ini
   fi
   PlayTuneAndDiod=$(grep "^PlayTuneAndDiod=" /home/pi/roc.ini | cut -c17- | tr -d "\n\r")
   GetSetting OLAServerIP
   GetSetting OLAServerPort
   GetSetting OLAServerHTTPS
   GetSetting EventId
   GetSetting OLACardReadoutComPort
   GetSetting OLACardReadoutShowMenu
   GetSetting OLACardReadoutFontSize
   GetSetting OLACardReadoutShowTime
   GetSetting IoTConnectionOrder
   GetSetting UseMQTT
   cp /home/pi/roc.ini /boot/ROC/ROC_settings_right_now_READ_ONLY.txt
#   GetSetting SSIDPasswd
   GetSetting NewPasswd
   rm -f /home/pi/ROC_settings.ini
#   SSIDPassw=$(grep "^SSIDPasswd" /home/pi/roc.ini | cut --delimiter== --fields=2)
#   maskedSSIDPassw=${SSIDPassw:0:1}
#   aaa=1
#   while [ $aaa -le `expr ${#SSIDPassw} - 2` ]; do
#      maskedSSIDPassw=$maskedSSIDPassw"*"
#      let "aaa += 1"
#   done
#   maskedSSIDPassw=$maskedSSIDPassw${SSIDPassw:$aaa:1}
#   echo SSIDPasswd=$maskedSSIDPassw >> /boot/ROC/ROC_settings_right_now_READ_ONLY.txt
   sed -i 's/$/\r/' /boot/ROC/ROC_settings_right_now_READ_ONLY.txt
   echo '<html><body>' > /home/pi/www/wwwroot/settings.html
   while read line; do
      echo '<br>'$line >> /home/pi/www/wwwroot/settings.html
   done </boot/ROC/ROC_settings_right_now_READ_ONLY.txt
   echo '<br></body></html>' >> /home/pi/www/wwwroot/settings.html
   cp /home/pi/roc.ini /home/pi/10/roc.ini.txt
}


nowDate=$(date +"%Y-%m-%d")
nowTime=$(date +"%T")
rm -f /home/pi/punches/emitserver/SI-status*
rm -f /home/pi/punches/callhome/*
rm -f /home/pi/punches/clusterfriendping/*
rm -f /home/pi/punches/sendmqtt/MCH*
rm -f /home/pi/punches/sendmqtt/COD*
rm -f /home/pi/.xsession-errors
rm -Rf /home/pi/.cache/mozilla/firefox/
rm -Rf /root/.cache/mozilla/firefox/
rm -f /home/pi/nohup.out
rm -f /home/pi/code_*
rm -f /home/pi/Memory*
mv -f /home/pi/raw* /home/pi/9/ &> /dev/null
mv -f /home/pi/SI-callhome-* /home/pi/10/ &> /dev/null
find /home/pi/punches/ -name 'SI-*' -mmin +600 -delete
sed -i '/^Power OFF ALL!/d' /home/pi/www/wwwroot/results/ResultListSlave.txt
sed -i '/^Reboot ALL!/d' /home/pi/www/wwwroot/results/ResultListSlave.txt
mkdir /home/pi/10/diplomaimages
chmod 777 /home/pi/10/diplomaimages/
# ln -s /home/pi/10/diplomaimages/ /home/pi/www/wwwroot/diploma/diplomaimages
cp /home/pi/www/wwwroot/diploma/first.jpg /home/pi/10/diplomaimages/
echo $nowDate $nowTime - Starting init.sh | tee -a /home/pi/10/init.log
#rasprev=$(grep -Po '^Revision\s*:\s*\K[[:xdigit:]]{4}' /proc/cpuinfo)
#if [ $rasprev == 7 ] || [ $rasprev == 8 ] || [ $rasprev == 9 ]; then
#   # Raspberry Pi model A, no built in network interface...
#   # Lets fake a Raspi-similar MAC from the last 3 bytes of CPU-serial.
#   # A normal rasp has B827EBxxxxxx as MAC where xxxxxx is the cpu serial. Lets us B827EA for others. It's not used by anyone so far.
#   echo RaspBerry Pi Model A, faking MAC-address... >> /home/pi/10/init.log
#   awk '/^Serial/ {print "b827ea" substr($3,1+length($3)-6)}' /proc/cpuinfo > /home/pi/10/macaddr.txt
#else
#   ifconfig eth0 | awk '/HWaddr/ {print $5}' | sed 's/://g' > /home/pi/10/macaddr.txt
#fi
#if [ ! -s /home/pi/10/macaddr.txt ]; then
#   # Getting the MAC failed, device without eth0 network interface.
#   # Lets fake a Raspi-similar MAC from the last 3 bytes of CPU-serial.
#   # A normal rasp has B827EBxxxxxx as MAC where xxxxxx is the cpu serial. Lets us B827EA for others. It's not used by anyone so far.
#   echo No MAC-address from eth0... Faking MAC-address... >> /home/pi/10/init.log
#   awk '/^Serial/ {print "b827ea" substr($3,1+length($3)-6)}' /proc/cpuinfo > /home/pi/10/macaddr.txt
#fi

## Förenklar nedanstående... Bara kolla om eth0 finns, då används MAC-adress, annars konstruera en...
if (ifconfig | grep eth0 &> /dev/null); then
   echo Raspbeery Pi with eth0. Getting MAC from eth0... >> /home/pi/10/init.log
#   ifconfig eth0 | awk '/HWaddr/ {print $5}' | sed 's/://g' > /home/pi/10/macaddr.txt
   ifconfig eth0 | awk '/ether/ {print $2}' | sed 's/://g' > /home/pi/10/macaddr.txt
elif (ifconfig | grep wlan0 &> /dev/null); then
   echo Raspbeery Pi without eth0 but with wlan0. Getting MAC from wlan0... >> /home/pi/10/init.log
   ifconfig wlan0 | awk '/ether/ {print $2}' | sed 's/://g' > /home/pi/10/macaddr.txt
else
   # Getting the MAC failed, so we are probably on a Raspi_Model.A.
   # We can fake a Raspi-similar MAC from the last 3 bytes of CPU-serial.
   # (see also http://www.raspberrypi.org/forums/viewtopic.php?p=90975)
   echo Rasp A, A+ or get MAC failed. Faking MAC from CPU-serial number... >> /home/pi/10/init.log
   awk '/^Serial/ {print "b827ea" substr($3,1+length($3)-6)}' /proc/cpuinfo > /home/pi/10/macaddr.txt
fi
macaddr=$(</home/pi/10/macaddr.txt)
macaddrhex=\\x${macaddr:0:2}\\x${macaddr:2:2}\\x${macaddr:4:2}\\x${macaddr:6:2}\\x${macaddr:8:2}\\x${macaddr:10:2}
echo Computer name is $HOSTNAME. >> /home/pi/10/init.log
echo MAC address is $macaddr. >> /home/pi/10/init.log
rocversion=$(</home/pi/rocversion)
rocrevision=$(</home/pi/rocrevision)

source /home/pi/shared.sh

old_PunchingSystem=$(grep "^PunchingSystem" /home/pi/roc.ini | cut -c16- | tr -d "\n\r")
if [ "a$old_PunchingSystem" = "a" ]; then
   old_PunchingSystem="SportIdent"
fi

route -n | grep 'UG[ \t]' | awk '{print $2}' > /home/pi/10/defgateway.txt
defgateway=$(</home/pi/10/defgateway.txt)
online=0
restarts=$(</home/pi/numberofrestarts.txt)

if ! ls /home/pi/updateroc.txt &> /dev/null; then
#   cp /home/pi/roc.ini /home/pi/updateroc.txt
   sed '/# Local setting/,+1 d' /home/pi/roc.ini > /home/pi/updateroc.txt
fi
ROCFunction=$(grep "^FunctionId" /home/pi/roc.ini | cut -c12- | tr -d "\n\r")
echo The ROC has function number $ROCFunction. >> /home/pi/10/init.log
echo The ROC has function number $ROCFunction.
# IoTConnectionOrder=""
GetAllSettings
ExecuteNewSettings





# OSKAR Ta bort detta
#nohup nethogs eth0 -t -d 60 -v2 > /home/pi/nethogs.log &








SIRAP=$(grep "^SIRAP=" /home/pi/roc.ini)
SIRAP=${SIRAP:6}
SIRAPServerIP=$(grep "^SIRAPServerIP=" /home/pi/roc.ini)
SIRAPServerIP=${SIRAPServerIP:14}
SIRAPServerPort=$(grep "^SIRAPServerPort=" /home/pi/roc.ini)
SIRAPServerPort=${SIRAPServerPort:16}
NoInternetNeeded=0
if ! [ ${#SIRAP} == 0 ]; then
   if [ "$SIRAP" = "Y" ]; then
      if ! [ ${#SIRAPServerIP} == 0 ]; then
         if ! [ ${#SIRAPServerPort} == 0 ]; then
            echo Use SIRAP - ServerIP:$SIRAPServerIP ServerPort:$SIRAPServerPort
            echo Use SIRAP - ServerIP:$SIRAPServerIP ServerPort:$SIRAPServerPort >> /home/pi/10/init.log
            NoInternetNeeded=1
         fi
      fi
   fi
fi
#DiplomaMaster=$(grep "^DiplomaMaster" /home/pi/roc.ini)
#DiplomaMaster=${DiplomaMaster:14}
#Diploma=$(grep "^Diploma=" /home/pi/roc.ini)
#Diploma=${Diploma:8}
#if [ "$DiplomaMaster" = "Y" ] || [ "$Diploma" = "Y" ]; then
if [ "$ROCFunction" = "3" ] || [ "$ROCFunction" = "4" ] || [ "$ROCFunction" = "14" ] || [ "$ROCFunction" = "15" ]; then
   # To make Diploma and OLA card readout ROCs go on even when no internet connection exists...
   NoInternetNeeded=1
fi
#PrewarningRelay=$(grep "^PrewarningRelay=" /home/pi/roc.ini)
#PrewarningRelay=${PrewarningRelay:16}
#if [ "$PrewarningRelay" = "Y" ]; then
if [ "$ROCFunction" = "13" ]; then
   # To make PrewarningRelay ROCs go on even when no internet connection exists...
   NoInternetNeeded=1
fi
#KvarISkogen=$(grep "^KvarISkogen=" /home/pi/roc.ini)
#KvarISkogen=${KvarISkogen:12}
#if [ "$KvarISkogen" = "Y" ]; then
if [ "$ROCFunction" = "5" ]; then
   # To make KvarISkogen ROCs go on even when no internet connection exists...
   NoInternetNeeded=1
fi
if [ "$ROCFunction" = "6" ] || [ "$ROCFunction" = "7" ]; then
   # To make Result ROCs go on even when no internet connection exists...
   NoInternetNeeded=1
fi
SendDirectRadiocraft=$(grep "^SendDirectRadiocraft=" /home/pi/roc.ini | cut -c22- | tr -d "\n\r")
if [ "$SendDirectRadiocraft" = "Y" ]; then
   # To make Radiocraft ROCs go on even when no internet connection exists...
   NoInternetNeeded=1
fi

# Punchingsystem

punchingsystem=$(grep "^PunchingSystem" /home/pi/roc.ini | cut -c16- | tr -d "\n\r")
if [ "a$punchingsystem" = "a" ]; then
   punchingsystem="SportIdent"
fi

if [ "$ROCFunction" = "1" ] || [ "$ROCFunction" = "2" ] || [ "$ROCFunction" = "3" ] || [ "$ROCFunction" = "8" ] || [ "$ROCFunction" = "9" ] || [ "$ROCFunction" = "10" ] || [ "$ROCFunction" = "11" ] || [ "$ROCFunction" = "12" ]; then
   nowTime=$(date +"%T")
   echo $nowDate $nowTime - Using punchingsystem $punchingsystem... >> /home/pi/10/init.log

   echo $nowDate $nowTime - Starting Radio Online Control | tee -a /home/pi/10/init.log
   rm -f /home/pi/ttystart_*
   rm -f /home/pi/ttyready_*
   case $punchingsystem in
      EmitRS232)
         /home/pi/startEmitRS232roc.sh
         ;;
      EmitECU)
         /home/pi/startEmitECUroc.sh
         ;;
      SportIdent)
         /home/pi/startSIroc.sh $online
         ;;
      *)
         echo Unknown punching system choosen, $punchingsystem! | tee -a /home/pi/10/init.log
         /home/pi/startSIroc.sh $online
         ;;
   esac
fi

echo PlayTuneAndDiod=$PlayTuneAndDiod >>/home/pi/10/init.log

## Fix av Håkan för Teltonika
   if [ "$IoT" = "N" ]; then

firstround=0
while [ $online = 0 ] && [ $NoInternetNeeded \< 6 ]; do
   defgateway=$(route -n | grep 'UG[ \t]' | awk '{print $2}' | head -c -1)
  # If DNS-redirected... change to google DNS...
   ROCDNS=$(timeout 10s nslookup -timeout=2 roc.olresultat.se | grep Address: | awk 'NR==2' | cut --delimiter=' ' --fields=2 | head -c -1)
   if ( [ "a$ROCDNS" = "a$defgateway" ] ) && ( [ "a$defgateway" != "a" ] || [ "a$(echo $ROCDNS | cut -d "." -f 1,2)" = "a192.168" ] ); then
      echo Changing DNS-server to 8.8.8.8 because of DNS-redirection in action from your DNS-server... >>/home/pi/10/init.log
      echo nslookup of roc.olresultat.se is $ROCDNS... >>/home/pi/10/init.log
      echo Default gateway is $defgateway... >>/home/pi/10/init.log
      sudo echo domain localdomain > /home/pi/10/resolv.conf.new
      sudo echo search localdomain. >> /home/pi/10/resolv.conf.new
      sudo echo nameserver 8.8.8.8 >> /home/pi/10/resolv.conf.new
      sudo cp /home/pi/10/resolv.conf.new /etc/resolv.conf
   fi
   if [ "$IoT" = "N" ]; then
      if [ "a$defgateway" != "a" ]; then
         curl --ipv4 --connect-timeout 5 --max-time 8 --user admin:admin http://$defgateway/userRpm/StatusRpm.htm > /home/pi/10/signal.html
         cat /home/pi/10/signal.html | grep -A1 -m1 mobileParam | tail -n 1 | cut --delimiter=, --fields=3 | sed -e 's/^[ \t]*//' > /home/pi/10/signal.txt
         signal=$(</home/pi/10/signal.txt)
         echo Signal=$signal >> /home/pi/10/init.log
      fi
   fi
#   localIP=$(hostname -I)
#   The above does not work with multiple IP addresses...
# Below does not work on Raspbian buster
#   localIP=$(ip route get 1 | awk '{print $NF;exit}')
   localIP=$(ip route get 1 | sed -n -e 's/.*src //p' | sed -n -e 's/ .*//p')
   echo "Local IP-address: $localIP" >> /home/pi/10/init.log
   echo "Local IP-address: $localIP"
   rasphardware=$(cat /proc/cpuinfo | grep 'Revision' | awk '{print $3}' | sed 's/^1000//')
   timetoonline=$(cat /proc/uptime | awk '{print $1}' | sed 's/\(.*\)\.\(.*\)/\1/')
   echo TimeToOnline=$timetoonline >> /home/pi/10/init.log
   curl --ipv4 --connect-timeout 8 --max-time 10 "https://roc.olresultat.se/$rocversion/receivedata.php?function=callhome&command=set&computername=$HOSTNAME&macaddr=$macaddr&signalstrength=$signal&rocversion=$rocversion&rocrevision=$rocrevision&timetoonline=$timetoonline&localipaddress=$localIP&rasphardware=$rasphardware" > /home/pi/10/callhome.txt
   cat /home/pi/10/callhome.txt | grep "Hi there" > /home/pi/10/callhome2.txt
   echo "Hi there $macaddr!!!" > /home/pi/10/callhome3.txt
   if (diff -b /home/pi/10/callhome3.txt /home/pi/10/callhome2.txt > /dev/null) ; then
      nowTime=$(date +"%T")
      echo $nowDate $nowTime >> /home/pi/10/init.log
      echo ===ONLINE=== >> /home/pi/10/init.log
      echo "The files are the same! Callhome has arrived :-)"
      echo It took $(cat /proc/uptime | awk '{print $1}' | sed 's/\(.*\)\.\(.*\)/\1/') seconds to get online. >> /home/pi/10/init.log
      online=1
   else
      echo "Callhome has not arrived..."
      nowTime=$(date +"%T")
      echo $nowDate $nowTime - Retrying Callhome init.sh >> /home/pi/10/init.log
      wpa_cli reconnect > /dev/null
   fi
   if [ $firstround = 0 ]; then
      firstround=1
      nowTime=$(date +"%T")
      echo $nowDate $nowTime - Starting 3g-script, sakis3g.sh...  >> /home/pi/10/init.log
      ModemAPN=$(grep "^ModemAPN=" /home/pi/roc.ini | cut -c10- | tr -d "\n\r")
      APN_User=$(grep "^APN_User=" /home/pi/roc.ini | cut -c10- | tr -d "\n\r")
      APN_Pass=$(grep "^APN_Pass=" /home/pi/roc.ini | cut -c10- | tr -d "\n\r")
      ModemPIN=$(grep "^ModemPIN=" /home/pi/roc.ini | cut -c10- | tr -d "\n\r")
#      nohup /home/pi/sakis3g.sh > /home/pi/10/sakis3g.txt &
      if (lsusb -t | grep -q "cdc_ncm"); then
         echo Found cdc_ncm modem. Activating...  >> /home/pi/10/init.log
         touch /home/pi/10/ncm_start.txt
         counter=1
         until (grep "successfully connected the modem" /home/pi/10/ncm_start.txt) || [ $counter -gt 10 ]; do
            echo Try number $counter to start ncm modem... >> /home/pi/10/init.log
            for device in $(mmcli -L | grep ModemManager | awk '{print $1}'); do mmcli -m $device --simple-connect="apn=$ModemAPN" > /home/pi/10/ncm_start.txt; done
            sleep 1
            ((counter++))
         done
         dhclient -v
      fi
      if (lsusb -t | grep -q "Driver=qmi"); then
         qmi_device="/dev/cdc-wdm0"
         wanport=$(qmicli --device=$qmi_device --device-open-proxy --get-wwan-iface)
         echo Found qmi-modem on port $qmi_device and network interface $wanport. Activating...  >> /home/pi/10/init.log
         if (grep "ModemPIN" /home/pi/roc.ini); then
            echo Setting PIN for modem on device $qmi_device. >> /home/pi/10/init.log
            qmicli --device=$qmi_device -p --dms-uim-verify-pin=PIN,$ModemPIN
         fi
         touch /home/pi/10/qmi_start.txt
         counter=1
         until (grep "Network started" /home/pi/10/qmi_start.txt) || [ $counter -gt 10 ]; do
            echo Try number $counter to start qmi modem on port $qmi_device... >> /home/pi/10/init.log
            qmicli --device=$qmi_device --device-open-proxy --wds-start-network="ip-type=4,apn=$ModemAPN" --client-no-release-cid > /home/pi/10/qmi_start.txt
            sleep 1
            ((counter++))
         done
         dhclient –v
      fi
      sed -i "/wwan0/d" /etc/dhcpcd.conf
      if (lsusb -t | grep -q "cdc_mbim"); then
         echo Found mbim-modem. Activating...  >> /home/pi/10/init.log
         mbim_device="/dev/cdc-wdm0"
         rm -f /etc/mbim_network.conf
         echo "APN=$ModemAPN" | tee /etc/mbim-network.conf
         echo "APN_User=$APN_User" | tee -a /etc/mbim-network.conf
         echo "APN_Pass=$APN_Pass" | tee -a /etc/mbim-network.conf
         echo "APN_AUTH=" | tee -a /etc/mbim-network.conf
         echo "PROXY=yes" | tee -a /etc/mbim-network.conf
         if (grep "ModemPIN" /home/pi/roc.ini); then
            echo Setting PIN for modem on device $mbim_device. >> /home/pi/10/init.log
            mbimcli -d $mbim_device -p --enter-pin=$ModemPIN
         fi
         touch /home/pi/10/mbim_start.txt
         counter=1
         until (grep "Network started successfully" /home/pi/10/mbim_start.txt) || [ $counter -gt 6 ]; do
            echo Try number $counter to start mbim modem on port $mbim_device... >> /home/pi/10/init.log
            mbim-network $mbim_device start > /home/pi/10/mbim_start.txt
            sleep 1
            ((counter++))
         done

         IPData=$(mbimcli -d $mbim_device -p --query-ip-configuration)
         echo $IPData >> /home/pi/10/mbim_IP.txt
         ipv4_address="none"

            function parse_ip {
               #      IP [0]: '10.134.203.177/30'
               local line_re="IP \[([0-9]+)\]: '(.+)'"
               local input=$1
               if [[ $input =~ $line_re ]]; then
                  local ip_cnt=${BASH_REMATCH[1]}
                  local ip=${BASH_REMATCH[2]}
               fi
               echo "$ip"
            }

            function parse_gateway {
               #    Gateway: '10.134.203.178'
               local line_re="Gateway: '(.+)'"
               local input=$1
               if [[ $input =~ $line_re ]]; then
                  local gw=${BASH_REMATCH[1]}
               fi
               echo "$gw"
            }

            function parse_dns {
               #      DNS [0]: '10.134.203.177/30'
               local line_re="DNS \[([0-9]+)\]: '(.+)'"
               local input=$1
               if [[ $input =~ $line_re ]]; then
                  local dns_cnt=${BASH_REMATCH[1]}
                  local dns=${BASH_REMATCH[2]}
               fi
               echo "$dns"
            }

            function parse_mtu {
               #        MTU: '1500'
               local line_re="MTU: '([0-9]+)'"
               local input=$1
               if [[ $input =~ $line_re ]]; then
                  local mtu=${BASH_REMATCH[1]}
               fi
               echo "$mtu"
            }

         while read -r line || [[ -n "$line" ]] ; do
            [ -z "$line" ] && continue
            case "$line" in
               *"IPv4 configuration available: 'none'"*)
                  state="start"
                  continue
               ;;
               *"IPv4 configuration available"*)
                  state="ipv4"
                  continue
               ;;
               *"IPv6 configuration available: 'none'"*)
                  state="start"
                  continue
               ;;
               *"IPv6 configuration available"*)
                  state="ipv6"
                  continue
               ;;
            esac
            case "$state" in
               "ipv4")
                  case "$line" in
                     *"IP"*)
                        row=$(parse_ip "$line")
                        ipv4_address=("$row")
                        continue
                     ;;
                     *"Gateway"*)
                        row=$(parse_gateway "$line")
                        ipv4_gateway="$row"
                        continue
                     ;;
                     *"DNS"*)
                        row=$(parse_dns "$line")
                        ipv4_dns=("$row")
                        continue
                     ;;
                     *"MTU"*)
                        row=$(parse_mtu "$line")
                        ipv4_mtu="$row"
                        continue
                     ;;
                  esac
               ;;
            esac
         done <<< "$IPData"

         if [ "$ipv4_address" = "none" ]; then
            echo Did not get an IP-address from device. Aborting... >> /home/pi/10/init.log
         else
#            sed -i "/wwan0/d" /etc/dhcpcd.conf
            sed -i "$ a interface wwan0    # wwan0" /etc/dhcpcd.conf
            sed -i "$ a static ip_address=$ipv4_address    # wwan0" /etc/dhcpcd.conf
            sed -i "$ a static routers=$ipv4_gateway    # wwan0" /etc/dhcpcd.conf
            sed -i "$ a static domain_name_servers=$ipv4_dns    # wwan0" /etc/dhcpcd.conf

            echo Setting IP-address $ipv4_address, gateway $ipv4_gateway and DNS $ipv4_dns on interface wwan0 >> /home/pi/10/init.log

#            dhclient -v
            dhcpcd --rebind wwan0
         fi
      fi
   fi
   if [ $NoInternetNeeded \> 0 ]; then
      let "NoInternetNeeded += 1"
   fi
   sleep 2
done
fi

if [ $NoInternetNeeded \> 1 ] && [ $online = 0 ]; then
   echo Not connected to ROC server, but told internet is not needed, continuing... | tee -a /home/pi/10/init.log
#   NoInternetNeeded=1
else
#   if [ $NoInternetNeeded \> 1 ]; then
#      NoInternetNeeded=1
#   fi
#   curl --ipv4 --connect-timeout 8 --max-time 10 "http://rocdns.olresultat.se/rocdns.php?ver=$rocversion" > /home/pi/10/rocdns.web
#   if [[ $i =~  \. ]]; then
#      cat /home/pi/10/rocdns.web > /home/pi/10/rocdns.txt
#   else
#      echo roc.olresultat.se > /home/pi/10/rocdns.txt
#   fi
#   rocdns=$(</home/pi/10/rocdns.txt)
   dir=1
   while [ $dir -le 10 ]; do
      if [ -d "/home/pi/$dir/" ]; then
         if ls /home/pi/$dir/totalNumberOfSirapPunches.txt &> /dev/null; then
            totalNumberOfSirapPunches=$(</home/pi/$dir/totalNumberOfSirapPunches.txt)
            sirapDate=$(date -r /home/pi/$dir/totalNumberOfSirapPunches.txt +%F)
            echo $totalNumberOfSirapPunches SIRAP punches to report to server from /home/pi/$dir/ at $sirapDate...  >> /home/pi/10/init.log
            curl --ipv4 --connect-timeout 8 --max-time 10 "https://roc.olresultat.se/$rocversion/receivedata.php?function=callhome&command=reportsirappunches&macaddr=$macaddr&date=$sirapDate&totalNumberOfSirapPunches=$totalNumberOfSirapPunches" >> /home/pi/10/sendSirapPunches.log
            rm -f /home/pi/$dir/totalNumberOfSirapPunches.txt
         fi
         if ls /home/pi/$dir/totalNumberOfDiplomas.txt &> /dev/null; then
            totalNumberOfDiplomas=$(</home/pi/$dir/totalNumberOfDiplomas.txt)
            diplomaDate=$(date -r /home/pi/$dir/totalNumberOfDiplomas.txt +%F)
            echo $totalNumberOfDiplomas diplomas to report to server from /home/pi/$dir/ at $diplomaDate...  >> /home/pi/10/init.log
            curl --ipv4 --connect-timeout 8 --max-time 10 "https://roc.olresultat.se/$rocversion/receivedata.php?function=callhome&command=reportdiploma&macaddr=$macaddr&date=$diplomaDate&totalNumberOfDiplomas=$totalNumberOfDiplomas" >> /home/pi/10/sendDiplomas.log
            rm -f /home/pi/$dir/totalNumberOfDiplomas.txt
         fi
      fi
      let "dir += 1"
   done
   cat /home/pi/10/callhome.txt | grep "Last updated configuration:" > /home/pi/10/callhomeLUC.txt
   cluc=$(</home/pi/10/callhomeLUC.txt)
   cluc=${cluc:28:19}
   echo Last updated configuration from server: $cluc | tee -a /home/pi/10/init.log
   if ls /home/pi/cluc.txt &> /dev/null; then
      cluclocal=$(</home/pi/cluc.txt)
   fi
   echo $cluc> /home/pi/cluc.txt
   echo "Last updated configuration from local: $cluclocal" | tee -a /home/pi/10/init.log
#   if [ "$cluclocal" \< "$cluc" ] || (grep -q "Diploma=Y" /home/pi/roc.ini); then
#       curl --ipv4 --max-time 10 "https://roc.olresultat.se/$rocversion/receivedata.php?function=onlineunits&command=getconfig&unitid=$macaddr" > /home/pi/10/updateroc.txt
       updatedconfigfromserver=N
       if (grep -q "===END_CONFIG===" /home/pi/10/callhome.txt); then
          sed -n '/START_CONFIG/,/END_CONFIG/{/START_CONFIG/b;/END_CONFIG/b;p}' /home/pi/10/callhome.txt > /home/pi/10/updateroc.txt
#          if ! (diff -b /home/pi/10/updateroc.txt /home/pi/updateroc.txt) ; then
             echo "Updating ROC with new settings from webserver and locally..." | tee -a /home/pi/10/init.log
             cp /home/pi/10/updateroc.txt /home/pi/updateroc.txt
             updatedconfigfromserver=Y
#          fi
       fi
#   fi
#        If Diploma, force fetching new settings if DiplomaImageViewer is ordered from screen config, because that order is sent through resultGetOrder.sh...
#   if [ "$cluclocal" \< "$cluc" ] || (grep -q "=" /boot/ROC/ROC_settings.ini) || (grep -q "Diploma=Y" /home/pi/roc.ini); then
fi


if [ "$UseMQTT" = "Y" ]; then
   echo Starting sendMQTT.py >> /home/pi/10/init.log
   nohup /usr/bin/python3 -u /home/pi/sendMQTT.py &> /home/pi/10/sendMQTT.out &
fi


## Kommenterat nedan. Settings som tas bort from local settings file is not removed...
#   if [ "A$updatedconfigfromserver" = "AY" ] || (grep -q "=" /boot/ROC/ROC_settings.ini) || (grep -q "Diploma=Y" /home/pi/roc.ini); then
#      GetAllSettings
#   fi
   GetAllSettings
   ExecuteNewSettings

# If UseMQTT has been changed in GetAllSettings...
if [ "$UseMQTT" = "Y" ]; then
   if (( $(ps aux | grep sendMQTT | wc -l) \< 2 )); then
      echo Starting sendMQTT.py >> /home/pi/10/init.log
      nohup /usr/bin/python3 -u /home/pi/sendMQTT.py &> /home/pi/10/sendMQTT.out &
   fi
fi

#   if [ "$cluclocal" \< "$cluc" ] || (grep -q "=" /boot/ROC/ROC_settings.ini); then
   if [ "A$updatedconfigfromserver" = "AY" ] || (grep -q "=" /boot/ROC/ROC_settings.ini); then

      # Make changes ordered from web server

      ROCFunction=$(grep "^FunctionId" /home/pi/roc.ini)
      ROCFunction=${ROCFunction:11}
      if [ "$ROCFunction" = "3" ]; then
# Diploma online control
         DiplomaImageUploadCounterLocal=$(</home/pi/diploma/DiplomaImageUploadCounter.txt)
         tempvar=$(grep "^DiplomaImageUploadCounter" /home/pi/roc.ini)
         tempvar=${tempvar:26}
         if ( [ "a$tempvar" != "a$DiplomaImageUploadCounterLocal" ] ) || ( grep -q "^<body>" /home/pi/diploma/DIPLOM.jpg ) || (! (ls /home/pi/diploma/DIPLOM.jpg &> /dev/null)); then
            echo Downloading new DIPLOM.jpg. DiplomaImageUploadCounterLocal=$DiplomaImageUploadCounterLocal and DiplomaImageUploadCounter=$tempvar.
            echo Downloading new DIPLOM.jpg. DiplomaImageUploadCounterLocal=$DiplomaImageUploadCounterLocal and DiplomaImageUploadCounter=$tempvar. >> /home/pi/10/init.log
            curl --ipv4 --connect-timeout 8 --max-time 10 "https://roc.olresultat.se/DiplomaImages/$macaddr.jpg" > /home/pi/diploma/DIPLOM_new.jpg
            echo $tempvar>/home/pi/diploma/DiplomaImageUploadCounter.txt
            if ( [ -s /home/pi/diploma/DIPLOM_new.jpg ] ) && ( ! (grep -q "^<body>" /home/pi/diploma/DIPLOM_new.jpg )); then
               mv -f /home/pi/diploma/DIPLOM_new.jpg /home/pi/diploma/DIPLOM.jpg
               echo Download of new DIPLOM.jpg successful!
               echo Download of new DIPLOM.jpg successful! >> /home/pi/10/init.log
            else
               SendMessage "init.sh" "Download of new DIPLOM.jpg failed! Keeping existing DIPLOM.jpg!" "2" "/home/pi/10/init.log"
            fi
         fi
      fi

      tempvar=$(sed -n '/removePunchesROC/s/^.*\(.\{1\}\)$/\1/p' /home/pi/roc.ini)
      if [ "$tempvar" = "Y" ]; then
         echo Removing any cached punches in /home/pi directory...
         echo Removing any cached punches in /home/pi directory... >> /home/pi/10/init.log
         rm -f /home/pi/SI-*
         rm -f /home/pi/raw-*
         rm -f /home/pi/punches/in/SI-*
         rm -f /home/pi/punches/out/SI-*
         rm -f /home/pi/punches/emitserver/SI-*
         rm -f /home/pi/punches/remotein/SI-*
         rm -f /home/pi/punches/backuproute/SI-*
         rm -Rf /home/pi/1
         rm -Rf /home/pi/2
         rm -Rf /home/pi/3
         rm -Rf /home/pi/4
         rm -Rf /home/pi/5
         rm -Rf /home/pi/6
         rm -Rf /home/pi/7
         rm -Rf /home/pi/8
         rm -Rf /home/pi/9
         echo Removed punches locally as ordered! >> /home/pi/10/init.log
         curl --ipv4 --connect-timeout 8 --max-time 10 "https://roc.olresultat.se/$rocversion/receivedata.php?function=onlineunits&command=removePunchesROCdone&unitid=$macaddr" > /home/pi/10/removePunchesROCdone.txt
      fi

      if [ $1 = "noupdate" ]; then
         tempvar=$(sed -n '/UpdateROC/s/^.*\(.\{1\}\)$/\1/p' /home/pi/roc.ini)
         if [ "$tempvar" = "Y" ]; then
            echo Time to update ROC!
            echo Time to update ROC! >> /home/pi/10/init.log
            curl --ipv4 --max-time 10 "https://roc.olresultat.se/$rocversion/newversion.php?function=newversion&command=getupdate&unitid=$macaddr"  > /home/pi/update.txt
            counted=$(grep -c ^ /home/pi/update.txt)
            number=$(head -1 /home/pi/update.txt)
            if [ "$counted" = "$number" ]; then
               echo Correct number of rows in update.txt file. Start updating ROC!
               echo Correct number of rows in update.txt file. Start updating ROC! >> /home/pi/10/init.log
               exit 10
            fi
         fi
      fi

      tempvar=$(grep "^NewComputerName" /home/pi/roc.ini)
      tempvar=${tempvar:16}
      tempcn=$(</etc/hostname)
      reboot="N"
      if [ "a$tempvar" != "a" ]; then
         if [ "$tempvar" != "$tempcn" ]; then
            reboot="Y"
            if [ "a$tempcn" = "anewroc" ]; then
               raspi-config --expand-rootfs
            fi
            echo Changeing computer name to $tempvar...
            echo Changeing computer name to $tempvar... >> /home/pi/10/init.log
            echo $tempvar>/home/pi/tempcn.txt
            cp /home/pi/tempcn.txt /etc/hostname
            rm -f /home/pi/tempcn.txt
            sed -i "2s/.*/127.0.1.1       $tempvar/" /etc/hosts
         fi
      fi

#      tempvar=$(sed -n '/SSHUPnP/s/^.*\(.\{1\}\)$/\1/p' /home/pi/roc.ini)
#      if [ "$tempvar" = "Y" ]; then
#         echo Opening for SSH in firewall with UPnP...
#         upnpc -d 22 tcp &> /home/pi/10/upnpdelete.txt
#         upnpc -r 22 tcp &> /home/pi/10/upnp.txt
#      fi

      tempvar=$(grep "^NewPasswd" /home/pi/roc.ini)
      tempvar=${tempvar:10}
      if [ "a$tempvar" != "a" ]; then
         echo Changing passwd to $tempvar for Pi user...
         passwd pi<<EOF
$tempvar
$tempvar
EOF
         x11vnc -storepasswd $tempvar /home/pi/.vnc/passwd
         x11vnc -storepasswd $tempvar /root/.vnc/passwd
         echo $tempvar>/home/pi/.vnc/passwd2
         echo __BEGIN_VIEWONLY__>>/home/pi/.vnc/passwd2
         echo $tempvar>/root/.vnc/passwd2
         echo __BEGIN_VIEWONLY__>>/root/.vnc/passwd2

         curl --ipv4 --connect-timeout 8 --max-time 10 "https://roc.olresultat.se/$rocversion/receivedata.php?function=onlineunits&command=newpasswdset&unitid=$macaddr"
      fi

      tempvar=$(grep "^WiFiRegDomain" /home/pi/roc.ini)
      tempvar=${tempvar:14}
      if [ "a$tempvar" != "a" ]; then
         sed -i "s/REGDOMAIN\=.*/REGDOMAIN\=$tempvar/g" /etc/default/crda
      fi

      tempvar=$(grep "^sdtv_mode" /home/pi/roc.ini)
      if [ "a$tempvar" != "a" ]; then
         grep -q "sdtv_mode=" /boot/config.txt && sed -i "/sdtv_mode=/c\\$tempvar" /boot/config.txt || echo "$tempvar" >> /boot/config.txt
      fi

      tempvar=$(grep "^sdtv_aspect" /home/pi/roc.ini)
      if [ "a$tempvar" != "a" ]; then
         grep -q "sdtv_aspect=" /boot/config.txt && sed -i "/sdtv_aspect=/c\\$tempvar" /boot/config.txt || echo "$tempvar" >> /boot/config.txt
      fi

      tempvar=$(grep "^framebuffer_width" /home/pi/roc.ini)
      if [ "a$tempvar" != "a" ]; then
         grep -q "framebuffer_width=" /boot/config.txt && sed -i "/framebuffer_width=/c\\$tempvar" /boot/config.txt || echo "$tempvar" >> /boot/config.txt
      fi

      tempvar=$(grep "^framebuffer_height" /home/pi/roc.ini)
      if [ "a$tempvar" != "a" ]; then
         grep -q "framebuffer_height=" /boot/config.txt && sed -i "/framebuffer_height=/c\\$tempvar" /boot/config.txt || echo "$tempvar" >> /boot/config.txt
      fi

      tempvar=$(grep "^overscan_left" /home/pi/roc.ini)
      if [ "a$tempvar" != "a" ]; then
         grep -q "overscan_left=" /boot/config.txt && sed -i "/overscan_left=/c\\$tempvar" /boot/config.txt || echo "$tempvar" >> /boot/config.txt
      fi

      tempvar=$(grep "^overscan_right" /home/pi/roc.ini)
      if [ "a$tempvar" != "a" ]; then
         grep -q "overscan_right=" /boot/config.txt && sed -i "/overscan_right=/c\\$tempvar" /boot/config.txt || echo "$tempvar" >> /boot/config.txt
      fi

      tempvar=$(grep "^overscan_top" /home/pi/roc.ini)
      if [ "a$tempvar" != "a" ]; then
         grep -q "overscan_top=" /boot/config.txt && sed -i "/overscan_top=/c\\$tempvar" /boot/config.txt || echo "$tempvar" >> /boot/config.txt
      fi

      tempvar=$(grep "^overscan_bottom" /home/pi/roc.ini)
      if [ "a$tempvar" != "a" ]; then
         grep -q "overscan_bottom=" /boot/config.txt && sed -i "/overscan_bottom=/c\\$tempvar" /boot/config.txt || echo "$tempvar" >> /boot/config.txt
      fi

      tempvar=$(grep "^enable_gpio_serial" /home/pi/roc.ini)
      tempvar=${tempvar:19}
      if [ "$tempvar" = "Y" ]; then
         echo Disabling serial console to enable gpio serial port >> /home/pi/10/init.log
         rpi-serial-console disable
         if ! (grep -q "^dtoverlay=pi3-disable-bt" /boot/config.txt); then
            echo "dtoverlay=pi3-disable-bt" | sudo tee -a /boot/config.txt > /dev/null
         fi
      else
         echo Enabling serial console because disabling gpio serial port >> /home/pi/10/init.log
         rpi-serial-console enable
         sed -i 's/ console=tty1//g' /boot/cmdline.txt
         sed -i 's/kgdboc=ttyAMA0,115200/kgdboc=ttyAMA0,115200 console=tty1/g' /boot/cmdline.txt
         if (grep -q "^dtoverlay=pi3-disable-bt" /boot/config.txt); then
            sed -i 's/dtoverlay=pi3-disable-bt//g' /boot/config.txt
         fi
      fi

   # End changes ordered from web server

      if [ "$reboot" = "Y" ]; then
         echo Rebooting because of ROC changing name! >> /home/pi/10/init.log
         sync
         if (( $restarts < 5 )); then
            killall monitor.sh minicallhome.sh
            reboot
            exit
         else
            echo Aborting reboot because of too many reboots without a complete reboot in between! >> /home/pi/10/init.log
         fi
      fi
   fi

tempvar=$(grep "^ScreenShowInfo" /home/pi/roc.ini)
tempvar=${tempvar:15}
ScreenShowInfo="N"
if [ "a$tempvar" != "a" ]; then
   ScreenShowInfo="Y"
fi

# Get and set time from web server
# Trust systemd-timesync from Raspbian Buster

#if [ $online == 1 ]; then 
#   online=0
#   while [ $online = 0 ]; do
##      raspdate=$(date +"%Y-%m-%d %H:%M:%S")
##      echo raspdate=$raspdate
#      curl --ipv4 --connect-timeout 8 --max-time 10 "https://roc.olresultat.se/$rocversion/gettime.php" > /home/pi/10/gettime.txt
#      raspdate=$(date +"%Y-%m-%d %H:%M:%S")
#      echo rasptime=$raspdate
#      webtime=$(</home/pi/10/gettime.txt)
#      echo webtime=$webtime
#      if [ "${webtime:0:19}" = "${raspdate:0:19}" ]; then
#         nowTime=$(date +"%T")
#         echo $nowDate $nowTime - Date and time is the same on webserver and Rasp  >> /home/pi/10/init.log
#         online=1
#      else
#         nowTime=$(date +"%T")
#         echo $nowDate $nowTime - Date and time is not the same on webserver and Rasp, setting clock. >> /home/pi/10/init.log
#         sudo date +"%Y-%m-%d %H:%M:%S" -s "$webtime"
#      fi
#      sleep 1
#   done
#fi

nowTime2=$(date +"%H-%M-%S")
for i in /home/pi/SI-*.txt; do mv "$i" "$i".sentafterreboot.$nowDate.$nowTime2.old &> /dev/null; done
for i in /home/pi/raw-*.txt; do mv "$i" "$i".sentafterreboot.$nowDate.$nowTime2.old &> /dev/null; done
for i in /home/pi/punches/in/SI-*.txt; do mv "$i" "$i".sentafterreboot.$nowDate.$nowTime2.old &> /dev/null; done

DiplomaMaster=$(grep "^DiplomaMaster=" /home/pi/roc.ini)
DiplomaMaster=${DiplomaMaster:14}
Diploma=$(grep "^Diploma=" /home/pi/roc.ini)
Diploma=${Diploma:8}
DiplomaImageViewer=$(grep "^DiplomaImageViewer=" /home/pi/roc.ini)
DiplomaImageViewer=${DiplomaImageViewer:19}
PrewarningRelay=$(grep "^PrewarningRelay=" /home/pi/roc.ini)
PrewarningRelay=${PrewarningRelay:16}
KvarISkogen=$(grep "^KvarISkogen=" /home/pi/roc.ini)
KvarISkogen=${KvarISkogen:12}
ROCFunction=$(grep "^FunctionId" /home/pi/roc.ini)
ROCFunction=${ROCFunction:11}

tempcn=$(</etc/hostname)
interface=$(ip route get 1 | sed -n -e 's/.*dev //p' | sed -n -e 's/ .*//p')
sed -i "s/.*allow-interfaces.*/allow-interfaces=$interface/g" /etc/avahi/avahi-daemon.conf
sed -i "s/.*host-name.*/host-name=$tempcn/g" /etc/avahi/avahi-daemon.conf
sed -i "s/.*netbios name = .*/   netbios name = $tempcn/g" /etc/samba/smb.conf
sed -i "s/.*domain-name.*/domain-name=local/g" /etc/avahi/avahi-daemon.conf
if [ "$ROCFunction" = "6" ]; then
   sed -i "s/.*host-name.*/host-name=ROCmaster/g" /etc/avahi/avahi-daemon.conf
   sed -i "s/.*netbios name = .*/   netbios name = ROCmaster/g" /etc/samba/smb.conf
else
   rm -f /home/pi/www/wwwroot/results/ROClist.html
fi
if [ "$ROCFunction" = "4" ]; then
   sed -i "s/.*host-name.*/host-name=ROCDiploma/g" /etc/avahi/avahi-daemon.conf
   sed -i "s/.*netbios name = .*/   netbios name = ROCDiploma/g" /etc/samba/smb.conf
fi
if [ "$ROCFunction" = "14" ]; then
   sed -i "s/.*host-name.*/host-name=ROCDiplomaImage/g" /etc/avahi/avahi-daemon.conf
   sed -i "s/.*netbios name = .*/   netbios name = ROCDiplomaImage/g" /etc/samba/smb.conf
fi
sync
# /etc/init.d/samba restart
systemctl restart smbd.service
/etc/init.d/avahi-daemon restart
nowTime=$(date +"%T")

# 6=Result Master, 7=Result Screen


if [ "$ROCFunction" = "15" ]; then
   echo $nowDate $nowTime - Starting OLA card readout >> /home/pi/10/init.log
   # Set 38400 bit/s
   OLACardReadoutComPort=$(grep "^OLACardReadoutComPort=" /home/pi/roc.ini | cut -c23- | tr -d "\n\r")
   echo -e "\xFF\x02\x7E\x01\x03" > /dev/$OLACardReadoutComPort
   sleep 0.2
   sudo stty -F /dev/$port cs8 38400 ignbrk -icrnl -imaxbel -opost -onlcr -isig -icanon -iexten -echo -echoe -echok -echoctl -echoke -noflsh -ixon -crtscts
   sudo stty -F /dev/$port 38400
   nohup startx &> /home/pi/10/startx.log &
fi

echo Signal strength is $signal% | tee -a /home/pi/10/init.log

if [ "$ROCFunction" = "1" ] || [ "$ROCFunction" = "2" ] || [ "$ROCFunction" = "3" ] || [ "$ROCFunction" = "8" ] || [ "$ROCFunction" = "9" ] || [ "$ROCFunction" = "10" ] || [ "$ROCFunction" = "11" ] || [ "$ROCFunction" = "12" ]; then
   nowTime=$(date +"%T")
   echo
   echo $nowDate $nowTime - ROC starting... waiting for com-ports to report status as started. init.sh | tee -a /home/pi/10/init.log
   echo
   files=$(ls /home/pi/ttystart_* 2> /dev/null | wc -l)
   if [ "$files" != "0" ]; then
      cd /home/pi
      ready=0
      while [ $ready = 0 ]; do
         ready=1
         for f in ttystart_*
         do
            file=ttyready_${f:9}
#            echo Filename=/home/pi/$file
            if ! ls $file &> /dev/null; then
               ready=0
            fi
         done
         files=$(ls /home/pi/ttystart_* 2> /dev/null | wc -l)
         if [ "$files" = "0" ]; then
            ready=1
         fi
         sleep 1
      done
   fi
   if [ "$punchingsystem" = "EmitRS232" ]; then
      if [ "$ScreenShowInfo" = "Y" ]; then
         nohup /home/pi/startEmitRS232roclater.sh &> /home/pi/10/startEmitRS232roclater.out | tail -f /home/pi/10/startEmitRS232roclater.out &
      else
         nohup /home/pi/startEmitRS232roclater.sh &> /home/pi/10/startEmitRS232roclater.out &
      fi
   else
      if [ "$punchingsystem" = "EmitECU" ]; then
         if [ "$ScreenShowInfo" = "Y" ]; then
            nohup /home/pi/startEmitECUroclater.sh &> /home/pi/10/startEmitECUroclater.out | tail -f /home/pi/10/startEmitECUroclater.out &
         else
            nohup /home/pi/startEmitECUroclater.sh &> /home/pi/10/startEmitECUroclater.out &
         fi
      else
         if [ "$ScreenShowInfo" = "Y" ]; then
            nohup /home/pi/startSIroclater.sh $online &> /home/pi/10/startSIroclater.out | tail -f /home/pi/10/startSIroclater.out &
         else
            nohup /home/pi/startSIroclater.sh $online &> /home/pi/10/startSIroclater.out &
         fi
         echo Starting history.sh >> /home/pi/10/init.log
         nohup /home/pi/history.sh &> /home/pi/10/history.out &
      fi
   fi
   nowTime=$(date +"%T")
   sync
   echo Starting sendPunches.se. >> /home/pi/10/init.log
   if [ "$ScreenShowInfo" = "Y" ]; then
      nohup /home/pi/sendPunches.sh $ROCDiplomaIP $ROCDiplomaImageIP &> /home/pi/10/sendPunches.out | tail -f /home/pi/10/sendPunches.out &
   else
      nohup /home/pi/sendPunches.sh $ROCDiplomaIP $ROCDiplomaImageIP &> /home/pi/10/sendPunches.out &
   fi
   if [ "$IoT" = "N" ]; then
      BackupRoute=$(grep "^BackupRoute" /home/pi/roc.ini | cut -c13- | tr -d "\n\r")
      if [ "$BackupRoute" = "Y" ]; then
         echo Starting backupRoute.sh because it has been ordered. | tee -a /home/pi/10/init.log
         nohup /home/pi/backupRoute.sh &> /home/pi/10/backupRoute.out &
      fi
   fi

   SendPunchesToEmitServer=$(grep "^EmitSendPunchesToEmitServer" /home/pi/roc.ini | cut -c29- | tr -d "\n\r")
   if [ "$SendPunchesToEmitServer" = "Y" ]; then
      echo Starting sendPunchesEmitServer.sh because it has been ordered. | tee -a /home/pi/10/init.log
      nohup /home/pi/sendPunchesEmitServer.sh &> /home/pi/10/sendPunchesEmitServer.out &
   fi
fi

# Send punches using Radiocraft if COM is not used.
SendDirectRadiocraft=$(grep "^SendDirectRadiocraft=" /home/pi/roc.ini | cut -c22- | tr -d "\n\r")
if (! [ "$ROCFunction" = "8" ] ) && [ "$SendDirectRadiocraft" = "Y" ]; then
   echo Starting Radiocraft program... | tee -a /home/pi/10/init.log
   nohup /home/pi/radiocraft &> /home/pi/10/radiocraft.out &
fi

# 8=online_control_si_raw_com
if [ "$ROCFunction" = "8" ] && [ "$SendDirectRadiocraft" = "Y" ]; then
   SendMessage "init.sh" "You can not have both SI-raw to COM and SendDirectRadiocraft at the same time. Please reconfigure!" "2" "/home/pi/10/init.log"
fi

echo Starting minicallhome.se. >> /home/pi/10/init.log
nohup /home/pi/minicallhome.sh &> /home/pi/10/minicallhome.out &

ifconfig > /home/pi/10/ifconfig.txt
defgateway=$(route -n | grep 'UG[ \t]' | awk '{print $2}' | head -c -1)
echo $defgateway > /home/pi/10/defgateway.txt
echo Default gateway is $defgateway | tee -a /home/pi/10/init.log
echo DNS-servers are:
echo $(cat /etc/resolv.conf | grep nameserver)
cat /etc/resolv.conf | grep nameserver >> /home/pi/10/init.log
nohup /home/pi/monitor.sh &> /home/pi/10/monitor.txt &
SendMessage "init.sh" "$macaddr is online." "0" "/home/pi/10/init.log"
echo $nowDate $nowTime - All is started! Sounding the bell! init.sh | tee -a /home/pi/10/init.log
if (! [ "$PlayTuneAndDiod" = "N" ]); then
   echo Playing and starting light diod. >> /home/pi/10/init.log
   python /home/pi/BerryClip/lightberry.py 5 on
   /home/pi/BerryClip/buzzPiezoStart.sh >> /home/pi/10/buzz.log
fi
echo It took $(cat /proc/uptime | awk '{print $1}' | sed 's/\(.*\)\.\(.*\)/\1/') seconds to start ROC. >> /home/pi/10/init.log
nowTime=$(date +"%T")
echo $nowDate $nowTime - Callhome ready in init.sh | tee -a /home/pi/10/init.log
sync
nohup /home/pi/init_end.sh &> /home/pi/10/init_end.log &
nowTime=$(date +"%T")
echo Computer name is $HOSTNAME. >> /boot/ROC/ROC_settings_right_now_READ_ONLY.txt
echo MAC address is $macaddr. >> /boot/ROC/ROC_settings_right_now_READ_ONLY.txt
echo Last booted at $nowDate $nowTime. >> /boot/ROC/ROC_settings_right_now_READ_ONLY.txt
echo $nowDate $nowTime - Ended script init.sh | tee -a /home/pi/10/init.log


