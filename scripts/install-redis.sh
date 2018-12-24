#!/bin/bash

# Check if Redis is already installed
if [ -f /home/vagrant/.redis-installed ]
then
  echo "Redis is already installed."
  exit 0
fi

touch /home/vagrant/.redis-installed

apt-get install -y build-essential tcl
cd /tmp
curl -O http://download.redis.io/redis-stable.tar.gz
tar xzvf redis-stable.tar.gz
cd redis-stable
make
make install
cd ..
cd ..
apt-get install -y redis-server
systemctl restart redis-server.service