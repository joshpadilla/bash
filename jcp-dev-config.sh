#!/bin/bash

##First update and upgrade before install
apt-get -y update && apt-get -y upgrade

##Install zsh and git packages
##apt-get -y install zsh && apt-get -y install git-core

##Install Oh My Zsh
##curl -L http://install.ohmyz.sh | sh

## The exit status of the last command run is 
## saved automatically in the special variable $?.
## Therefore, testing if its value is 0, is testing
## whether the last command ran correctly.
if [[ $? > 0 ]]
then
    echo "The command failed, exiting."
    exit
else
    echo "The command ran succesfuly, continuing with script."
fi
