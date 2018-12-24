#!/bin/bash

ROOT_PASSWORD=$1
USERNAME=$2
PASSWORD=$3
export DEBIAN_FRONTEND=noninteractive

# Check if MySQL is already installed
if [ -f /home/vagrant/.mysql57-installed ]
then
  echo "MySQL 5.7 is already installed."
  exit 0
fi

touch /home/vagrant/.mysql57-installed

# Remove MySQL
apt-get remove -y --purge mysql-server mysql-client mysql-common
apt-get autoremove -y
apt-get autoclean

rm -rf /var/lib/mysql
rm -rf /var/log/mysql
rm -rf /etc/mysql

apt-get update

debconf-set-selections <<< "mysql-server mysql-server/root_password password $ROOT_PASSWORD"
debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $ROOT_PASSWORD"
debconf-set-selections <<< "dbconfig-common dbconfig-common/mysql/app-pass password $ROOT_PASSWORD"
debconf-set-selections <<< "dbconfig-common	dbconfig-common/mysql/admin-pass password $ROOT_PASSWORD"
debconf-set-selections <<< "dbconfig-common	dbconfig-common/password-confirm password $ROOT_PASSWORD"
debconf-set-selections <<< "dbconfig-common	dbconfig-common/app-password-confirm password $ROOT_PASSWORD"

sudo apt-get install -y mysql-server mysql-client libmysqlclient-dev

# Configure MySQL 5.7 Remote Access
echo "bind-address = 0.0.0.0" | tee -a /etc/mysql/conf.d/mysql.cnf

service mysql restart

mysql --user="root" --password=$ROOT_PASSWORD -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' WITH GRANT OPTION;"
mysql --user="root" --password=$ROOT_PASSWORD -e "CREATE USER '$USERNAME'@'0.0.0.0' IDENTIFIED BY '$PASSWORD';"
mysql --user="root" --password=$ROOT_PASSWORD -e "CREATE USER '$USERNAME'@'%' IDENTIFIED BY '$PASSWORD';"
mysql --user="root" --password=$ROOT_PASSWORD -e "GRANT ALL PRIVILEGES ON *.* TO '$USERNAME'@'0.0.0.0' WITH GRANT OPTION;"
mysql --user="root" --password=$ROOT_PASSWORD -e "GRANT ALL PRIVILEGES ON *.* TO '$USERNAME'@'%' WITH GRANT OPTION;"
mysql --user="root" --password=$ROOT_PASSWORD -e "FLUSH PRIVILEGES;"

service mysql restart