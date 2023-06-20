#!/bin/bash
sudo -i
systemctl stop firewalld
setenforce 0
echo Create watchlog
cat >> /etc/sysconfig/watchlog << EOF
# Configuration file for my watchlog service
# Place it to /etc/sysconfig
 
# File and word in that file that we will be monit
WORD="ALERT"
LOG=/var/log/watchlog.log
EOF

echo Create watchlog.log
cat >> /var/log/watchlog.log << EOF
TEST
ALERT
WARNING
ERROR
CRITICAL
ALERT
EOF

echo Create watchlog.sh
cat >> /opt/watchlog.sh << EOF
#!/bin/bash
WORD=\$1
LOG=\$2

if grep \$WORD \$LOG &> /dev/null
then
logger "I found word, Master!"
else
exit 0
fi
EOF
chmod +x /opt/watchlog.sh

echo Create service
cat >> /etc/systemd/system/watchlog.service << EOF
[Unit]
Description=My watchlog service

[Service]
Type=oneshot
EnvironmentFile=/etc/sysconfig/watchlog
ExecStart=/opt/watchlog.sh \$WORD \$LOG
EOF

echo Create timer
cat >> /etc/systemd/system/watchlog.timer << EOF
[Unit]
Description=Run watchlog script every 30 second

[Timer]
# Run every 30 second
OnUnitActiveSec=30s
Unit=watchlog.service

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl start watchlog.service
systemctl start watchlog.timer

sleep 60
tail -n 100 /var/log/messages | grep Master

yum install epel-release -y && yum install spawn-fcgi php php-cli mod_fcgid httpd -y

sed '/SOCKET/s/^#//' -i /etc/sysconfig/spawn-fcgi
sed '/OPTIONS/s/^#//' -i /etc/sysconfig/spawn-fcgi

cat >> /etc/systemd/system/spawn-fcgi.service << EOF
[Unit]
Description=Spawn-fcgi startup service by Otus
After=network.target

[Service]
Type=simple
PIDFile=/var/run/spawn-fcgi.pid
EnvironmentFile=/etc/sysconfig/spawn-fcgi
ExecStart=/usr/bin/spawn-fcgi -n \$OPTIONS
KillMode=process

[Install]
WantedBy=multi-user.target
EOF
systemctl start spawn-fcgi
systemctl status spawn-fcgi

cat >> /usr/lib/systemd/system/httpd@.service << EOF
[Unit]
Description=The Apache HTTP Server
Wants=httpd-init.service

After=network.target remote-fs.target nss-lookup.target httpd-init.service

Documentation=man:httpd.service(8)

[Service]
Type=notify
Environment=LANG=C
EnvironmentFile=/etc/sysconfig/httpd-%I
ExecStart=/usr/sbin/httpd \$OPTIONS -DFOREGROUND
ExecReload=/usr/sbin/httpd \$OPTIONS -k graceful
# Send SIGWINCH for graceful stop
KillSignal=SIGWINCH
KillMode=mixed
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

echo "OPTIONS=-f conf/first.conf" >> /etc/sysconfig/httpd-first
echo "OPTIONS=-f conf/second.conf" >> /etc/sysconfig/httpd-second
mv /etc/httpd/conf/httpd.conf /etc/httpd/conf/first.conf
cp /etc/httpd/conf/first.conf /etc/httpd/conf/second.conf

sed -i 's/^Listen 80/Listen 8080/' /etc/httpd/conf/second.conf 
echo "PidFile /var/run/httpd-second.pid" >> /etc/httpd/conf/second.conf
systemctl daemon-reload
yum install net-tools -y
systemctl start httpd@{first,second}
netstat -tulnp | grep httpd
