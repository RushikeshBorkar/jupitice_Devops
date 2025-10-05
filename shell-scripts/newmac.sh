#mac-OS
#!/bin/bash

# --- Packages (Homebrew) ---
# Requires Homebrew. Install if missing:
if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew not found. Installing..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"
fi

brew install httpd mysql php redis wget git curl vim openssl gnu-tar

# --- Services (no systemctl on macOS) ---
brew services start httpd
brew services start redis
brew services start mysql
brew services start php

# --- MySQL root password + DBs ---
mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$2'; FLUSH PRIVILEGES;"

mysql -u root -p"$2" -e "CREATE DATABASE IF NOT EXISTS artemis;"
mysql -u root -p"$2" -e "CREATE DATABASE IF NOT EXISTS artemis_logs;"
mysql -u root -p"$2" -e "CREATE DATABASE IF NOT EXISTS artemis_companion;"
mysql -u root -p"$2" -e "CREATE DATABASE IF NOT EXISTS artemis_companion_logs;"

# --- Remote dumps ---
mysqldump -h pma-test.jupitice.com -u "lovenish" -p"$1" --single-transaction --quick --routines --triggers --events --no-tablespaces  "artemis_lovenish_companion_test" > /tmp/remote_dump1.sql
mysqldump -h pma-test.jupitice.com -u "lovenish" -p"$1" --single-transaction --quick --routines --triggers --events --no-tablespaces --no-data "artemis_lovenish_test_logs" > /tmp/remote_dump2.sql
mysqldump -h pma-test.jupitice.com -u "lovenish" -p"$1" --single-transaction --quick --routines --triggers --events --no-tablespaces  "artemis_lovenish_companion_test" > /tmp/remote_dump3.sql
mysqldump -h pma-test.jupitice.com -u "lovenish" -p"$1" --single-transaction --quick --routines --triggers --events --no-tablespaces --no-data "artemis_lovenish_companion_test_logs" > /tmp/remote_dump4.sql

# --- Import locally ---
mysql -u root -p"$2" "artemis" < /tmp/remote_dump1.sql
mysql -u root -p"$2" "artemis_logs" < /tmp/remote_dump2.sql
mysql -u root -p"$2" "artemis_companion" < /tmp/remote_dump3.sql
mysql -u root -p"$2" "artemis_companion_logs" < /tmp/remote_dump4.sql

mysql -u"root" -p"$2" -D"artemis" -e "SET GLOBAL sql_mode=(SELECT REPLACE(@@sql_mode,'ONLY_FULL_GROUP_BY',''));"

# --- phpMyAdmin (place directly in DocumentRoot) ---
BREW_PREFIX="$(brew --prefix)"
DOCROOT="$BREW_PREFIX/var/www/htdocs"
PMADIR="$DOCROOT/phpmyadmin"

mkdir -p "$DOCROOT"
cd /tmp
wget -q https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.tar.gz -O phpMyAdmin.tar.gz
tar xzf phpMyAdmin.tar.gz
rm -rf "$PMADIR"
mv phpMyAdmin-*-all-languages "$PMADIR"
rm -f phpMyAdmin.tar.gz
mkdir -p "$PMADIR/tmp"
# macOS apache user is _www
chown -R _www:_www "$PMADIR"

SECRET=$(openssl rand -hex 16)
cat >"$PMADIR/config.inc.php" <<PHP
<?php
\$cfg = [];
\$cfg['blowfish_secret'] = '${SECRET}';
\$cfg['TempDir'] = '$PMADIR/tmp';
\$cfg['Servers'][1]['auth_type'] = 'cookie';
\$cfg['Servers'][1]['host'] = 'localhost';
PHP

chown _www:_www "$PMADIR/config.inc.php"
chmod 640 "$PMADIR/config.inc.php"

# --- Enable PHP in Apache (Homebrew httpd + php-fpm) ---
HTTPD_CONF="$BREW_PREFIX/etc/httpd/httpd.conf"

# Ensure DirectoryIndex includes index.php
grep -q 'DirectoryIndex .*index.php' "$HTTPD_CONF" || \
  sed -i.bak 's/^DirectoryIndex .*/DirectoryIndex index.php index.html/' "$HTTPD_CONF"

# Enable required modules and PHP-FPM proxy (127.0.0.1:9000 is php-fpm default for Homebrew php)
if ! grep -q 'mod_proxy_fcgi' "$HTTPD_CONF"; then
  cat <<'APX' >> "$HTTPD_CONF"

# --- PHP via php-fpm ---
LoadModule proxy_module lib/httpd/modules/mod_proxy.so
LoadModule proxy_fcgi_module lib/httpd/modules/mod_proxy_fcgi.so
<FilesMatch \.php$>
    SetHandler "proxy:fcgi://127.0.0.1:9000"
</FilesMatch>
APX
fi

# Restart Apache to pick up changes
brew services restart httpd

# --- Node/NVM/PM2 (same as your script) ---
curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash
export NVM_DIR="$HOME/.nvm" && source "$NVM_DIR/nvm.sh" && nvm install --lts && npm install -g pm2

# --- Cleanup + info ---
rm -f /tmp/remote_dump*.sql
# Homebrew httpd listens on 8080 by default
echo "Done. phpMyAdmin: http://localhost:8080/phpmyadmin"
echo "MySQL root password: $2"

