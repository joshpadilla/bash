#!/bin/bash

#Six nodes are recommended, 3 master, 3 slave
#No diff for VM/Bare Metal
#Mesos clusters bare metal design
#For staging, VMs pract/efficient

#Import Mesosphere Archive Automatic Signing Key
apt-key adv --keyserver keyserver.ubuntu.com --recv E56151BF

#Add Ubuntu Mesosphere Repo
DISTRO=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
CODENAME=$(lsb_release -cs)
echo "deb http://repos.mesosphere.io/${DISTRO} ${CODENAME} main" | \
sudo tee /etc/apt/sources.list.d/mesosphere.list

#Normal Ubuntu Update Post Repo Add
apt-get -y update && apt-get -y upgrade

##Clean up after updates/upgrades
apt-get -y clean && apt-get -y autoclean
apt-get -y autoremove

apt-get -y install mesos

touch /etc/mesos/zk

#URL connect zookeeper file
zk://localhost:2181/mesos

##Exit status of last command run saved in var '$?'.
##Tests if value is 0, if greater than 0, command failed.
if [[ $? > 0 ]]
then
    echo "Mesos install/update script failed, exiting."
    exit
else
    echo "Ubuntu Update script success, finished."
fi





















