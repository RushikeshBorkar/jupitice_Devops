#!/bin/bash

#variables
environment=$1
artemisNginx="/etc/nginx/conf.d/artemis/${environment}-test.jupitice.com.conf"
companionNginx="/etc/nginx/conf.d/companion/${environment}-test-companion.jupitice.com.conf"
appName="artemis_${environment}_test"
companionName="artemis_${environment}_companion_test"

PASSWDDB=`cat /dev/urandom | tr -dc '[:alnum:]' | head -c 16`
mysqlpass=`head -30 ~/.bashrc | grep mysqlpass | head -1 | awk {'print $2'} |cut -b 12-27`
mysqlpassdemo=`head -30 ~/.bashrc | grep mysqlpassdemo | head -1|awk {'print $2'} |cut -b 16-31`

#user check exist or not
if getent passwd $1 > /dev/null 2>&1; then
    echo "SSH User Already Exists"
else
    echo "No, the user does not exist - Checking DB details"
fi

mysql -hpma-test.jupitice.com -uroot -p$mysqlpass mysql -e "select  User, Host from  user where User like '$environment%';" | grep $environment > /dev/null

if [ $? -ne 1 ];then
	echo "Db User Exist"
fi

##Database create proccess
echo "Delete user  $environment"
mysql -h pma-test.jupitice.com -u root -p"$mysqlpass" -e "DROP USER IF EXISTS '$environment'@'%'; FLUSH PRIVILEGES;"
for database_name in artemis_"$environment"_test artemis_"$environment"_test_logs artemis_"$environment"_companion_test artemis_"$environment"_companion_test_logs
do
    mysql -hpma-test.jupitice.com -uroot -p$mysqlpass -e "DROP DATABASE $database_name;"
done


# Get all process IDs for the user
PIDS=$(ps -u "$environment" -o pid=)

if [ -z "$PIDS" ]; then
    echo "No processes found for user $environment."
else
    echo "Processes found for user $environment. Killing all..."
    echo "$PIDS" | xargs kill -9
    echo "All processes for $environment have been terminated."
fi

# Delete user
if id "$environment" >/dev/null 2>&1; then
    echo "Deleting user $environment..."
    sudo userdel -r "$environment"
    
    if [ $? -eq 0 ]; then
        echo "User $environment deleted successfully."
    else
        echo "Failed to delete user $environment."
    fi
else
    echo "User $environment does not exist."
fi


##Nginx configuration
rm -rf /home/$environment
rm /etc/nginx/conf.d/artemis/$environment-test.jupitice.com.conf
rm /etc/nginx/conf.d/companion/$environment-test-companion.jupitice.com.conf

echo "####################################################################"
echo "Ofboarfing Process complete"
echo "####################################################################"

