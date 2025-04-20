
wget https://github.com/mypiandrew/quectel-cm/releases/download/V1.6.0.12/quectel-CM.tar.gz
ls
unzip quectel-CM.tar.gz
tar -xzvf quectel-CM.tar.gz
ls -la
cd quectel-CM/
ls
./install.sh
cat README.sample.connection.txt
reboot


pm2 start '/usr/local/bin/quectel-CM -4 -f /var/log/quectel-CM.log' --restart-delay=10000 --watch
pm2 save
pm2 start /solutions/nbiot/monit_trm250.sh --watch
pm2 save

