  pm2 start '/usr/local/bin/quectel-CM -4 -f /var/log/quectel-CM.log' --restart-delay=10000 --watch
  pm2 start /solutions/nbiot/monit_trm250.sh --watch

  pm2 save
