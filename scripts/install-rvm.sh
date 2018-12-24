#!/usr/bin/env bash

# Check if RVM is already installed
if [ -f /home/vagrant/.rvm-installed ]
then
  echo "RVM is already installed."
  exit 0
fi

touch /home/vagrant/.rmv-installed

gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
curl -sSL https://get.rvm.io | bash -s 'stable'