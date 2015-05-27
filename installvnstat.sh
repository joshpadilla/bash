#!/bin/bash

# This script installs vnstat in a server. 
# If the distro has an official package for it, it will
# use it. Else, it will download the tarball from the
# site and install it. But in this case the script will
# fix all paths so files are installed in /usr/local
# instead, as per the LSB FSH.
#
# - Yves Junqueira <yves@rimuhosting.com>
# Copyright 2007 Rimuhosting.com
#
# Last update: 2007-08-23

set -e
VERSION="1.4"

install_generic() {
    # this will replace a possibly installed version

    wget -O "vnstat-$VERSION.tar.gz" "http://humdi.net/vnstat/vnstat-$VERSION.tar.gz"
    tar zxf "vnstat-$VERSION.tar.gz"
    cd "vnstat-$VERSION"
    make
    if [ -d /etc/ppp/ip-up.d ]; then 
        echo "Installing ppp/ip-up script";
        cp -f pppd/vnstat_ip-up /etc/ppp/ip-up.d/vnstat; 
    fi
    if [ -d /etc/ppp/ip-down.d ]; then 
        echo "Installing ppp/ip-down script"; 
        cp -f pppd/vnstat_ip-down /etc/ppp/ip-down.d/vnstat; 
    fi
    install -d /var/lib/vnstat
    install -m 755 src/vnstat /usr/local/bin
    install -m 644 man/vnstat.1 /usr/local/share/man/man1
    install -m 644 cron/vnstat /etc/cron.d
    sed -i /etc/cron.d/vnstat -e 's/bin/local\/bin/g'
}

install_apt() {

    apt-get install vnstat

}

if [ "$UID" -ne "0" ]; then 
    echo "root required and you're not root. exiting..."
    exit 1
fi

(( apt-cache show vnstat > /dev/null 2>&1 && install_apt ) || install_generic )

for i in $(cat /proc/net/if_inet6 |awk '{print $6}'|grep -v lo); do
    vnstat -u -i "$i"
done

echo "Install done. Wait a minute and 1Mb of traffic and then type 'vnstat'"

