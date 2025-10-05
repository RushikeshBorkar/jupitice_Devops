#!/bin/bash

apt update -y
apt upgrade -y
apt install -y nginx mysql-server mysql-client php-fpm php-mysql php-cli php-common php-json php-zip php-gd php-mbstring php-curl php-xml php-bcmath wget tar openssl git curl vim redis-server
systemctl enable --now nginx
systemctl enable --now redis-server
systemctl enable --now php*-fpm

mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$2'; FLUSH PRIVILEGES;"
mysql -u root -p"$2" -e "CREATE DATABASE IF NOT EXISTS artemis;"
mysql -u root -p"$2" -e "CREATE DATABASE IF NOT EXISTS artemis_logs;"


mysqldump -h pma-test.jupitice.com -u "lovenish" -p"$1" --single-transaction --quick --routines --triggers --events --no-tablespaces  "artemis_lovenish_test" > /tmp/remote_dump1.sql
mysqldump -h pma-test.jupitice.com -u "lovenish" -p"$1" --single-transaction --quick --routines --triggers --events --no-tablespaces --no-data "artemis_lovenish_test_logs" > /tmp/remote_dump2.sql


mysql -u root -p"$2" "artemis" < /tmp/remote_dump1.sql
mysql -u root -p"$2" "artemis_logs" < /tmp/remote_dump2.sql


cd /usr/share
wget -q https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.tar.gz -O phpMyAdmin.tar.gz
tar xzf phpMyAdmin.tar.gz
rm -rf /usr/share/phpmyadmin
mv phpMyAdmin-*-all-languages phpmyadmin
rm -f phpMyAdmin.tar.gz
mkdir -p /usr/share/phpmyadmin/tmp
chown -R www-data:www-data /usr/share/phpmyadmin

SECRET=$(openssl rand -hex 16)
cat >/usr/share/phpmyadmin/config.inc.php <<PHP
<?php
\$cfg = [];
\$cfg['blowfish_secret'] = '${SECRET}';
\$cfg['TempDir'] = '/usr/share/phpmyadmin/tmp';
\$cfg['Servers'][1]['auth_type'] = 'cookie';
\$cfg['Servers'][1]['host'] = 'localhost';
PHP

chown www-data:www-data /usr/share/phpmyadmin/config.inc.php
chmod 640 /usr/share/phpmyadmin/config.inc.php

cat >/etc/nginx/sites-available/phpmyadmin <<'NGINX'
server {
    listen 80;
    server_name _;

    # Redirect /phpmyadmin to /phpmyadmin/
    location = /phpmyadmin {
        return 301 /phpmyadmin/;
    }

    location /phpmyadmin/ {
        alias /usr/share/phpmyadmin/;
        index index.php index.html;
        try_files $uri $uri/ =404;
    }

    location ~ ^/phpmyadmin/(.+\.php)$ {
        alias /usr/share/phpmyadmin/$1;
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME /usr/share/phpmyadmin/$1;
    }
}
NGINX

ln -s /etc/nginx/sites-available/phpmyadmin /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
systemctl reload nginx

