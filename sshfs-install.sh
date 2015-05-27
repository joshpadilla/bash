#!/bin/bash

##Install & verify sshfs on server & client
apt-get install sshfs

##Update-upgraded
apt-get -y update && apt-get -y upgrade

##Update-upgrade clean-up
apt-get -y clean && apt-get -y autoclean
apt-get -y autoremove

##Fuse group usr add 
gpasswd -a $USER fuse



##Exit status of last command run saved in var '$?'.
##Tests if value is 0, if greater than 0, command failed.
if [[ $? > 0 ]]
then
    echo "Ubuntu Update script failed, exiting."
    exit
else
    echo "Ubuntu Update script success, finished."
fi


