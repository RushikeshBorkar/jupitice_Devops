#!/bin/bash

apt update -y
apt upgrade -y
apt install -y apache2 mysql-server mysql-client php libapache2-mod-php php-mysql php-cli php-common php-json php-zip php-gd php-mbstring php-curl php-xml php-bcmath wget tar openssl git curl vim redis-server
systemctl enable --now apache2
systemctl enable --now redis-server

mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$2'; FLUSH PRIVILEGES;"
mysql -u root -p"$2" -e "CREATE DATABASE IF NOT EXISTS artemis;"
mysql -u root -p"$2" -e "CREATE DATABASE IF NOT EXISTS artemis_logs;"
mysql -u root -p"$2" -e "CREATE DATABASE IF NOT EXISTS artemis_companion;"
mysql -u root -p"$2" -e "CREATE DATABASE IF NOT EXISTS artemis_companion_logs;"

mysqldump -h pma-test.jupitice.com -u "lovenish" -p"$1" --single-transaction --quick --routines --triggers --events --no-tablespaces  "artemis_lovenish_test" > /tmp/remote_dump1.sql
mysqldump -h pma-test.jupitice.com -u "lovenish" -p"$1" --single-transaction --quick --routines --triggers --events --no-tablespaces --no-data "artemis_lovenish_test_logs" > /tmp/remote_dump2.sql
mysqldump -h pma-test.jupitice.com -u "lovenish" -p"$1" --single-transaction --quick --routines --triggers --events --no-tablespaces  "artemis_lovenish_companion_test" > /tmp/remote_dump3.sql
mysqldump -h pma-test.jupitice.com -u "lovenish" -p"$1" --single-transaction --quick --routines --triggers --events --no-tablespaces --no-data "artemis_lovenish_companion_test_logs" > /tmp/remote_dump4.sql

mysql -u root -p"$2" "artemis" < /tmp/remote_dump1.sql
mysql -u root -p"$2" "artemis_logs" < /tmp/remote_dump2.sql
mysql -u root -p"$2" "artemis_companion" < /tmp/remote_dump3.sql
mysql -u root -p"$2" "artemis_companion_logs" < /tmp/remote_dump4.sql

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

cat >/etc/apache2/conf-available/phpmyadmin.conf <<'APACHE'
Alias /phpmyadmin /usr/share/phpmyadmin
<Directory /usr/share/phpmyadmin>
    Options FollowSymLinks
    DirectoryIndex index.php
    AllowOverride All
    Require all granted
</Directory>

<Directory /usr/share/phpmyadmin/setup/lib>
    Require all denied
</Directory>
APACHE

a2enconf phpmyadmin
systemctl reload apache2

mysql -u"root" -p"$2" -D"artemis" -e "SET GLOBAL sql_mode=(SELECT REPLACE(@@sql_mode,'ONLY_FULL_GROUP_BY',''));"

#curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash
#export NVM_DIR=\"\$HOME/.nvm\" && source \$NVM_DIR/nvm.sh && nvm install --lts && npm install -g pm2

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
nvm install node
npm install pm2 -g

rm -f /tmp/remote_dump*.sql

git clone git@gitlab.com:jupitice/artemis.git
cd artemis/config/
cp $HOME/artemisConfig.json $3-local.json
sed -i 's/pass_wd/'$2'/g' $3-local.json
npm i
npm run start --env=$3-local

echo "Done. phpMyAdmin: http://localhost/phpmyadmin"
echo "MySQL root password: $2"
