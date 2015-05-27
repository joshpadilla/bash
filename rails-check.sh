#!/bin/bash
# check some things before updateing rails
#

echo " * Checking OS" 

if [ -e /etc/redhat-release ]; then
  DISTRO="redhat"
elif [ -e /etc/debian_version ]; then
  DISTRO="debian"
fi

if [ $DISTRO == "redhat" ]; then
echo " Running Centos Version:"
cat /etc/redhat-release
fi

if [ $DISTRO == "debian" ]; then
echo " * Running Debian based distro, version info:"
	if [ ! -f /usr/bin/lsb_release ]; then
	echo " * lsb_release not installed, installing"
	apt-get install lsb-release
	fi
lsb_release -a
fi

echo "" 
echo " * Checking Ruby ruby path and version"  
which ruby
ruby --version 

echo ""
echo " * Checking Rails rails path and version"
which rails
rails --version

echo ""
echo " * Checking if Passenger or Mongrel running" 

if [ $(ps auxf | grep -v grep | grep -ci passenger) -ne 0 ]; then
echo " * mod_passenger process detected" 
fi

if [ $(ps auxf | grep -v grep | grep -ci mongrel) -ne 0 ]; then
echo " * mongrel process detected"
fi 

echo ""
echo " ^ If no output above some other rails server running"

echo "" 
echo " * Checking all locally installed gems" 
gem list --local

echo "" 
echo "Read about exploit here: https://groups.google.com/forum/#!topic/rubyonrails-security/61bkgvnSGTQ/discussion" 
