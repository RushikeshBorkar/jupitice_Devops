#!/bin/bash

#variables
environment=$1
key=$2
port1=`shuf -i 1000-9999 -n 1`
port2=`shuf -i 1000-9999 -n 1`
artemisConfig="/home/${environment}/artemis/config/config.json"
companionConfig="/home/${environment}/artemis-companion/config/config.json"
artemisPATH="/home/${environment}/artemis/"
companionPATH="/home/${environment}/artemis-companion/"
artemisNginx="/etc/nginx/conf.d/artemis/${environment}-test.jupitice.com.conf"
companionNginx="/etc/nginx/conf.d/companion/${environment}-test-companion.jupitice.com.conf"
appName="artemis_${environment}_test"
companionName="artemis_${environment}_companion_test"

PASSWDDB=`cat /dev/urandom | tr -dc '[:alnum:]' | head -c 16`
mysqlpass=`head -30 .bashrc | grep mysqlpass | head -1 | awk {'print $2'} |cut -b 12-27`
mysqlpassdemo=`head -30 .bashrc | grep mysqlpassdemo | head -1|awk {'print $2'} |cut -b 16-31`

#user check exist or not
if getent passwd $1 > /dev/null 2>&1; then
    echo "SSH User Already Exists"
    exit 1
else
    echo "No, the user does not exist"
fi

mysql -hpma-test.jupitice.com -uroot -p$mysqlpass mysql -e "select  User, Host from  user where User like '$environment%';" | grep $environment > /dev/null

if [ $? -ne 1 ];then
	echo "Db User Already Exist"
	exit 1
fi

##Database create proccess
echo "User created $environment"
mysql -hpma-test.jupitice.com -uroot -p$mysqlpass -e "CREATE USER '$environment'@'%' IDENTIFIED BY '$PASSWDDB';"
mysql -hpma-test.jupitice.com -uroot -p$mysqlpass -e "GRANT SELECT, LOCK TABLES ON *.* TO '$environment'@'%';"
for database_name in artemis_"$environment"_test artemis_"$environment"_test_logs artemis_"$environment"_companion_test artemis_"$environment"_companion_test_logs
do
    mysql -hpma-test.jupitice.com -uroot -p$mysqlpass -e "create database $database_name;"
    mysql -hpma-test.jupitice.com -uroot -p$mysqlpass -e "GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER, CREATE TEMPORARY TABLES, CREATE VIEW, EVENT, TRIGGER, SHOW VIEW, CREATE ROUTINE, ALTER ROUTINE, EXECUTE ON "$database_name".* TO '$environment'@'%';"
done

for dump_name in artemis_master_test artemis_master_test_logs artemis_master_companion_test artemis_master_companion_test_logs
do
	echo "Now, importing data to the artemis database"
	mysqldump -h 10.82.162.7 -u companion-test -p$mysqlpassdemo --single-transaction --set-gtid-purged=OFF $dump_name > /usr/local/src/newjoiner/$dump_name.sql
done

##Dump restore
mysql -hpma-test.jupitice.com -uroot -p$mysqlpass artemis_"$environment"_test < /usr/local/src/newjoiner/artemis_master_test.sql
mysql -hpma-test.jupitice.com -uroot -p$mysqlpass artemis_"$environment"_test_logs < /usr/local/src/newjoiner/artemis_master_test_logs.sql
mysql -hpma-test.jupitice.com -uroot -p$mysqlpass artemis_"$environment"_companion_test < /usr/local/src/newjoiner/artemis_master_companion_test.sql
mysql -hpma-test.jupitice.com -uroot -p$mysqlpass artemis_"$environment"_companion_test_logs < /usr/local/src/newjoiner/artemis_master_companion_test_logs.sql

echo "Installing Node And Pm2"
adduser --disabled-password --gecos "" $environment > /dev/null


for repo in artemis artemis-companion
do
	git clone git@gitlab.com:jupitice/$repo.git -b develop /home/${environment}/$repo
done

##artemis-ssh add
cp -ar /usr/local/src/newjoiner/.ssh /home/${environment}/
chown -R ${environment}. /home/${environment}/.ssh

##artemis
cp /usr/local/src/newjoiner/artemis.json $artemisConfig
sed -i 's/portno/'$port1'/g' $artemisConfig
sed -i 's/username/'$environment'/g' $artemisConfig
sed -i 's/passwddb/'$PASSWDDB'/g' $artemisConfig
#companion
cp /usr/local/src/newjoiner/companion.json $companionConfig
sed -i 's/portno/'$port2'/g' $companionConfig
sed -i 's/username/'$environment'/g' $companionConfig
sed -i 's/passwddb/'$PASSWDDB'/g' $companionConfig

cp -ar /usr/local/src/newjoiner/.ssh /home/${environment}
echo "${key}" >> /home/${environment}/.ssh/authorized_keys
chown -R ${environment}. /home/${environment}/.ssh
chown -R ${environment}. /home/${environment}/*
cd $artemisPATH
sudo su -c "npm i" -s /bin/sh ${environment}
sudo su -c "npm run build" -s /bin/sh ${environment}
sudo su -c "NODE_ENV=config pm2 start app.cjs --name artemis_"$environment"_test" -s /bin/sh ${environment}
cd $companionPATH
sudo su -c "npm i" -s /bin/sh ${environment}
sudo su -c "NODE_ENV=config pm2 start app.cjs --name artemis_companion_"$environment"_test" -s /bin/sh ${environment}
sudo su -c "pm2 save" -s /bin/sh ${environment}
##Nginx configuration
cp /etc/nginx/conf.d/sample.conf $artemisNginx
cp /etc/nginx/conf.d/sample.conf $companionNginx
sed -i 's/1111/'$port1'/g' $artemisNginx
sed -i 's/1111/'$port2'/g' $companionNginx
sed -i 's/sample.jupitice.com/'$environment-test.jupitice.com'/g' $artemisNginx
sed -i 's/sample.jupitice.com/'$environment-test-companion.jupitice.com'/g' $companionNginx
nginx -t > /dev/null 2>&1

if [[ $? == 0 ]]; then
    echo "Nginx config valid, proceeding with reload"
    service nginx reload > /dev/null 2>&1
else
	echo "Nginx configtest failed, exiting without reload"
	exit 1
fi

for database_name in artemis_"$environment"_test artemis_"$environment"_test_logs artemis_"$environment"_companion_test artemis_"$environment"_companion_test_logs
do
	echo "Database Name: $database_name "
done
echo "####################################################################"
echo "Open the SSH terminal on your machine and run the following command:"
echo "# ssh ${environment}@test.jupitice.com"
echo "Artemis URL: https://${environment}-test.jupitice.com"
echo "Companion URL: https://${environment}-test-companion.jupitice.com"
echo "MySQL Credentails"
echo "PhpMyAdmin URL: https://pma-test.jupitice.com"
echo "username: $environment"
echo "password:  $PASSWDDB"
echo "####################################################################"

