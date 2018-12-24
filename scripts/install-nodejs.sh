#!/bin/bash

# Check if NodeJS is already installed
if [ -f /home/vagrant/.nodejs-installed ]
then
  echo "NodeJS is already installed."
  exit 0
fi

touch /home/vagrant/.nodejs-installed

curl -sL https://deb.nodesource.com/setup_10.x | sudo bash -
apt-get install -y nodejs