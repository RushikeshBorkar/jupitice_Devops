# Part 1: System Update & Basic Utilities
#!/bin/bash

# Update and upgrade system packages
apt update -y
apt upgrade -y

# Install essential packages
apt install -y wget tar openssl git curl vim

# Part 2: Install & Configure Nginx
# Install Nginx
apt install -y nginx

# Enable and start Nginx
systemctl enable --now nginx

# Part 3: Install & Configure Redis
# Install Redis server
apt install -y redis-server

# Enable and start Redis
systemctl enable --now redis-server

# Part 4: Install & Configure PHP
# Install PHP and extensions
apt install -y php-fpm php-mysql php-cli php-common php-json php-zip php-gd \
               php-mbstring php-curl php-xml php-bcmath

# Detect installed PHP version
PHP_VERSION=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")

# Enable and start PHP-FPM
systemctl enable --now php${PHP_VERSION}-fpm

# Part 5: Install & Configure MySQL
# Install MySQL server & client
apt install -y mysql-server mysql-client

# Set MySQL root password (argument $2)
mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$2'; FLUSH PRIVILEGES;"

# Create required databases
mysql -u root -p"$2" -e "CREATE DATABASE IF NOT EXISTS artemis;"
mysql -u root -p"$2" -e "CREATE DATABASE IF NOT EXISTS artemis_logs;"

# Part 6: Import Remote Databases
# Dump remote database (argument $1 = remote DB password)
mysqldump -h pma-test.jupitice.com -u "masterclean" -p"$1" \
  --single-transaction --quick --routines --triggers --events --no-tablespaces \
  "artemis_masterclean_test" > /tmp/remote_dump1.sql

# Dump only schema of logs DB
mysqldump -h pma-test.jupitice.com -u "masterclean" -p"$1" \
  --single-transaction --quick --routines --triggers --events --no-tablespaces \
  --no-data "artemis_masterclean_test_logs" > /tmp/remote_dump2.sql

# Import into local MySQL
mysql -u root -p"$2" "artemis" < /tmp/remote_dump1.sql
mysql -u root -p"$2" "artemis_logs" < /tmp/remote_dump2.sql

# Part 7: Install & Configure phpMyAdmin
# Download and extract phpMyAdmin
cd /usr/share
wget -q https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.tar.gz -O phpMyAdmin.tar.gz
tar xzf phpMyAdmin.tar.gz
rm -rf /usr/share/phpmyadmin
mv phpMyAdmin-*-all-languages phpmyadmin
rm -f phpMyAdmin.tar.gz

# Setup tmp directory for phpMyAdmin
mkdir -p /usr/share/phpmyadmin/tmp
chown -R www-data:www-data /usr/share/phpmyadmin

# Generate blowfish secret
SECRET=$(openssl rand -hex 16)

# Create phpMyAdmin config
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

# Part 8: Configure Nginx for phpMyAdmin
# Create phpMyAdmin Nginx config
cat >/etc/nginx/sites-available/phpmyadmin <<NGINX
server {
    listen 80;
    server_name _;

    location = /phpmyadmin {
        return 301 /phpmyadmin/;
    }

    location /phpmyadmin/ {
        root /usr/share/;
        index index.php index.html;
        try_files $uri $uri/ =404;
    }

    location ~ ^/phpmyadmin/(.+\.php)$ {
        root /usr/share/;
        fastcgi_pass unix:/run/php/php${PHP_VERSION}-fpm.sock;
        include snippets/fastcgi-php.conf;
        fastcgi_param SCRIPT_FILENAME $request_filename;
    }
}
NGINX

# Enable site & reload nginx
ln -s /etc/nginx/sites-available/phpmyadmin /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl reload nginx
