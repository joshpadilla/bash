#!/bin/bash

#
# $Id: installroundcube.sh 230 2012-06-01 04:45:17Z carl $
#

set -e 
VERSION=$(wget -q -O - http://roundcube.net/downloads | grep Stable | egrep -o '[0-9]\.[0-9]\.[0-9]')

if [ $VERSION != 0.7.2 ] ; then
  echo "! Version changed since this script was written, might want to check if something needs to be updated."
fi

MYPASS=$(pwgen -N 1 2> /dev/null||false)||true
if [ -z "$MYPASS" ] ; then
  echo "  Type a password for the new roundcubemail mysql user:"
  read MYPASS
fi

DATE=$(date +%Y)
echo "* Downloading roundcube $VERSION"
# Get url from download page
DOWNLOAD_URL=$(wget -q -O - http://roundcube.net/downloads | grep ${VERSION}.tar.gz | sed 's/.*href="//' | sed 's|/download.*||') 
wget -q $DOWNLOAD_URL
tar zxf roundcubemail-$VERSION.tar.gz

# FIXME everything below needs to be tested. 
cd roundcubemail-$VERSION
cd config
if [ ! -e db.inc.php ] ; then
  echo "Creating db.inc.php"
  sed -e "s|^\$rcmail_config\['db_dsnw'\].*|\$rcmail_config\['db_dsnw'\] = 'mysql://roundcube:$MYPASS@localhost/roundcubemail';|g"  db.inc.php.dist > db.inc.php
fi

if [ ! -e main.inc.php ] ; then
echo "Creating main.inc.php"
    sed -e "s|^\$rcmail_config\['default_host'\] = '';|\$rcmail_config\['default_host'\] = 'localhost';|g" main.inc.php.dist > main.inc.php
fi

echo "When asked, please type your mysql root password (or hit enter if it's blank)"
mysql -uroot -p -e "CREATE DATABASE roundcubemail; GRANT ALL ON roundcubemail.* TO 'roundcube'@'localhost' IDENTIFIED BY '$MYPASS'; FLUSH PRIVILEGES" || ( echo "ERROR: could not create 'roundcubemail' database." && exit 1 )

cd ../SQL
echo "Setting up Database"
mysql -uroundcube -p$MYPASS roundcubemail < mysql.initial.sql
cd ../../
if [ -e '/usr/local/roundcubemail' ] ; then mv /usr/local/roundcubemail /usr/local/roundcubemail.pre$DATE.$$ ; fi
mv roundcubemail-$VERSION /usr/local/roundcubemail

cd /usr/local/roundcubemail
cat <<EOF>> roundcubemail.conf
Alias /mail /usr/local/roundcubemail
EOF

if [ -d /etc/httpd/conf.d ] ; then
    # rhel-ish server
    ln -s /usr/local/roundcubemail/roundcubemail.conf /etc/httpd/conf.d/
    apachectl -S
elif [ -d /etc/apache2/conf.d ] ; then
    # debian-ish with apache2
    ln -s /usr/local/roundcubemail/roundcubemail.conf /etc/apache2/conf.d/
    apache2ctl -S
elif [ -d /etc/apache/conf.d ] ; then
    # debian-ish with apache
    ln -s /usr/local/roundcubemail/roundcubemail.conf /etc/apache/conf.d/
    apachectl -S
fi

echo "Now reload your apache server manually, please."
