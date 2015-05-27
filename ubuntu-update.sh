#!/bin/bash

##First update/upgrade as needed
apt-get -y update && apt-get -y upgrade

##Clean up after updates/upgrades
apt-get -y clean && apt-get -y autoclean
apt-get -y autoremove

##Exit status of last command run saved in var '$?'.
##Tests if value is 0, if greater than 0, command failed.
if [[ $? > 0 ]]
then
    echo "Ubuntu Update script failed, exiting."
    exit
else
    echo "Ubuntu Update script success, finished."
fi
