#!/bin/bash

sudo systemctl stop apache2
sudo systemctl stop mysql
sudo apt purge apache2* -y
sudo apt autoremove --purge -y
sudo rm -rf /etc/apache2 /var/www/html
sudo systemctl stop mysql
sudo apt purge mysql-server mysql-client mysql-common mysql-server-core-* mysql-client-core-* -y
sudo apt autoremove --purge -y
sudo rm -rf /etc/mysql /var/lib/mysql
sudo rm -rf /var/log/mysql /var/log/mysql.*
sudo apt purge php* -y
sudo apt autoremove --purge -y
sudo rm -rf /etc/php
sudo rm -rf /usr/share/phpmyadmin
sudo rm -rf /etc/apache2/conf-available/phpmyadmin.conf
sudo rm -rf /etc/apache2/conf-enabled/phpmyadmin.conf
sudo rm -rf /usr/share/phpmyadmin
sudo rm -rf /etc/apache2/conf-available/phpmyadmin.conf
sudo rm -rf /etc/apache2/conf-enabled/phpmyadmin.conf
sudo apt autoremove --purge -y
sudo apt clean
systemctl status apache2
systemctl status mysql
dpkg -l | grep -E "apache2|mysql|php"
