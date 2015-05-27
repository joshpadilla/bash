#!/bin/bash

#
# Automated Plesk installer, see http://sp.parallels.com/products/plesk/download/
#

if [ -e /etc/debian_version ]; then
  export DEBIAN_PRIORITY=critical
  export DEBIAN_FRONTEND=noninteractive
fi

if [ -z "${rootpasswd}" ]; then
  echo "  Need administrative user password for Plesk"
  echo -n "Enter 'admin' password now: " && read rootpasswd
  if [ $? -ne 0 ]; then echo "Bailing, no password known/provided"; exit 1; fi
fi
  
if [ -e /etc/init.d/webmin ]; then
  echo "* Disabling webmin to avoid conflicts"
  [ -e /etc/redhat-release ] && chkconfig --del webmin || update-rc.d -f webmin remove
  service webmin stop
fi

wget -q -O plesk-installer http://autoinstall.plesk.com/plesk-installer
bash plesk-installer  --no-clear --no-daemon --notify-email ${supportemail} --enable-xml-output --truncate-log


echo "* Setting admin user password"
if /usr/local/psa/bin/init_conf --check-configured; then 
  echo "Plesk admin password is already set, leaving.  Use /usr/local/psa/bin/init_conf -u -passwd secretpasswordhere to change that"
else
  /usr/local/psa/bin/init_conf --init  -passwd $rootpasswd -license_agreed true -name Administrator
  if [ $? -ne 0 ]; then 
    echo "Error setting Plesk admin password" >&2; 
    exit 1; 
  fi
  { export PSA_PASSWORD=${rootpasswd} && /usr/local/psa/admin/sbin/ch_admin_passwd; }
fi

echo "* Time to try logging in at https://$ipaddr:8443 as user admin password $rootpasswd"