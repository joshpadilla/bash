#!/bin/bash

if [ -f /etc/ntp.conf ]; then
	if grep -q '^server ntp.\.ny\.rimuhosting\.com' /etc/ntp.conf; then
		echo "NY NTP servers already configured"
		exit 1
	fi
	echo "Configuring NY NTP servers"
	sed -i 's/^\(server .*\)/#\1/g' /etc/ntp.conf
	echo "" >>/etc/ntp.conf
	echo "#New York NTP servers - Rimuhosting configured" >>/etc/ntp.conf
	echo "server ntp1.ny.rimuhosting.com" >>/etc/ntp.conf
	echo "server ntp2.ny.rimuhosting.com" >>/etc/ntp.conf
	if [ -n "$(pidof ntpd)" ]; then
                 echo "Restart ntp"
                 /etc/init.d/ntp restart &>/dev/null
                 /etc/init.d/ntpd restart &>/dev/null 
        fi

fi
