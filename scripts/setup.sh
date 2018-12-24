#!/bin/bash

# Update / Upgrade
apt-get update && sudo apt-get -y upgrade

# Install essentials packages
apt-get install -y git build-essential tcl libssl-dev curl

# Update / Upgrade again
apt-get update && sudo apt-get -y upgrade