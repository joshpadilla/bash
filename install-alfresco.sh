#!/bin/bash

#
# $Id: installalfresco.sh 21 2010-11-18 09:37:16Z deploy $
#

mysqluser=root
mysqlpass=""

function checkmysqlsetup() {
if [ -e /etc/psa/.psa.shadow ]; then
        mysqlpass=$(cat /etc/psa/.psa.shadow)
        mysqluser=admin
fi

if [ -e /root/.mysqlp ]; then
        mysqlpass=$(cat /root/.mysqlp)
fi
while [ -z "$mysqlpass" ]; do
        echo -n "MySQL root password? "
        read mysqlpass
        if [ ! -z "$mysqlpass" ]; then
                echo $mysqlpass > /root/.mysqlp
                chmod og= /root/.mysqlp
        fi
done

mysqladmin password "$mysqlpass" 2>/dev/null

if [ -e /etc/init.d/mysqld ]; then
        mysql=/etc/init.d/mysqld
else
        mysql=/etc/init.d/mysql
fi

if [ ! -x $mysql ]; then
        echo "No /etc/init.d/mysqld or /etc/init.d/mysql. Is MySQL installed?"
        return 1
fi

$mysql > /dev/null
if [ $? -ne 0 ]; then
        $mysql -u root -p$mysqlpass >/dev/null
        if [ $? -ne 0 ]; then
        $mysql start > /dev/null
        #$mysql status > /dev/null
        #if [ $? -ne 0 ]; then
        #       echo "Unable start MySQL"
        #       exit 1
        #fi
        fi
fi

if [ ! -e /root/.mysqlp ]; then
	echo "Need a /root/.mysqlp file with the mysql root user password in it" >&2
	return 1
fi
mysqlpass=$(cat /root/.mysqlp)

mysql -u $mysqluser -p$mysqlpass -e "use mysql;" 2> /dev/null
if [ $? -ne 0 ]; then
	echo "Unable to login to MySQL. Check/set the root password?"
	return 1
fi

}
checkmysqlsetup
if [ $? -ne 0 ]; then exit 1; fi

DATE=$(date +%Y-%m-%d)
if [ -e /usr/local/alfresco ]; then
	/etc/init.d/alfresco stop
	mv /usr/local/alfresco /usr/local/alfresco.$DATE
fi
mkdir -p /usr/local/alfresco
cd /usr/local/alfresco
version=1.4.0
# 2.0 results in an error like Ensure that the 'dir.root' property
 is pointing to the correct data location.
#version=2.0.0
wget http://optusnet.dl.sourceforge.net/sourceforge/alfresco/alfresco-community-tomcat-$version.tar.gz
if [ $? -ne 0 ]; then echo "download failed" >&2; exit 1; fi
tar xzf alfresco-community-tomcat-$version.tar.gz
if [ $? -ne 0 ]; then echo "untar failed" >&2; exit 1; fi

mysql -u $mysqluser -p$mysqlpass -e "use alfresco;" 2> /dev/null
if [ $? -ne 0 ]; then
	# Database doesn't exist. Create it.
	mysql -u $mysqluser -p"$mysqlpass" < extras/databases/mysql/db_setup.sql
else
	echo "Database 'alfresco' exists.  Skipping db create."
fi


mkdir -p tomcat/shared/classes/alfresco/extension.removed
mv tomcat/shared/classes/alfresco/extension/custom-db-and-data-context.xml tomcat/shared/classes/alfresco/extension/custom-db-connection.properties tomcat/shared/classes/alfresco/extension/custom-hibernate-dialect.properties tomcat/shared/classes/alfresco/extension.removed

adduser -s /sbin/nologin -d /usr/local/alfresco alfresco
wget -O /etc/init.d/tomcat http://proj.ri.mu/javainitscript
ln -sf /etc/init.d/tomcat  /etc/init.d/alfresco
replace 8005 8105 8009 8109 8080 8180 -- tomcat/conf/*.xml
/etc/init.d/alfresco start
ip=$(ifconfig | grep --after-context=1 "eth0 " | grep inet | cut -d: -f2 | cut -f1 -d' ')
chkconfig --level 35 $(basename $mysql) on
chkconfig --level 35 alfresco on
echo See alfresco running at "http://$ip:8180/alfresco"
wget -O - "http://$ip:8180/alfresco" --server-response  2>&1 | grep -qai 'Alfresco'
if [ $? -eq 0 ]; then echo 'Looks like Alfresco is loading correctly'; else
        echo "There could be a problem with Alfresco, it did not load as expected"
fi

