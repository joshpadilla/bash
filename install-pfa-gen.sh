#!/bin/bash

# Copyright Rimuhosting.com

# script to install postfix configs for postfixadmin
#
# distro agnostic
#
# TODO: improve mysql configuration and dependency
# TODO: improve services restarts, upstart, different names for init scripts, etc.
#

echo "This script is currently NOT maintained. Use for testing only, and at your own risk"

## Detect distro version
if [ -e /etc/redhat-release ]; then
     DISTRO="centos"
	if ! grep -q 'CentOS release 5' /etc/redhat-release; then
		echo "Error Centos 5.X required"
		exit 1
	fi
 elif [ -e /etc/debian_version ]; then
     DISTRO="debian"
fi


set_global_default_env(){
	## Postfixadmin default admin
	PFA_ADMIN_USER=admin@$(hostname)
	PFA_ADMIN_PASS=$(</dev/urandom tr -dc A-Za-z0-9 | head -c8)
	
	## Database credentials for postfixadmin
	PFA_DB_PASS=$(</dev/urandom tr -dc A-Za-z0-9 | head -c8)
	PFA_DB_USER="postfixadmin"
	PFA_DB_DATABASE="postfixadmin"
	
	# User for the mail storage
	VMAIL_USER="vmail"

	# Task to perform
	TASKS="all"
	FORCE="no"




}

install_deps(){
	
	## Install required packages and configure global enviroment	

	## TODO, the following is dirty. Check mysql is running- 
	if ! netstat -putan | grep -q 3306; then
		echo "Error: Mysql server is not running"
		return 1
	fi

	## Common packages
	#apt-get -y install 
	
	## Specific distribution packages
	if [ $DISTRO = "debian" ]; then
		export DEBIAN_FRONTEND=noninteractive
		apt-get -y install postfix-mysql php5-imap wwwconfig-common dbconfig-common dovecot-imapd dovecot-pop3d
		if dpkg -l | grep -q dovecot-postfix; then 
			apt-get -y --purge remove dovecot-postfix
		fi
		if dpkg -l | grep -q mail-stack-delivery; then
			apt-get -y --purge remove mail-stack-delivery
		fi	
		if dpkg -l | grep -q sasl2-bin; then
			apt-get -y --purge remove sasl2-bin
		fi

	fi
	if [ $DISTRO = "centos" ]; then
		if ! postconf -m | grep -q mysql; then
			package_version=$( apt-cache policy postfix | grep -B1 centosplus | head -n1 | sed 's/.* \([0-9:\.-]*centos\.mysql_pgsql\) .*/\1/g' )
			if [ -z $package_version ]; then
				echo "Error: could not find suitable postfix mysql package"
				return 1
			fi
			apt-get -y remove postfix
			apt-get -y install postfix\=$package_version
		fi
		apt-get -y install php-imap php-mbstring dovecot
		echo <<EOF "
#################################################################
#
# Warning: Postfix package has been installed from centosplus repository.
# Check your package pinning settings for the repositories if you
# want to avoid the postfix package be reinstalled/upgraded 
# with the base package
#
#################################################################
"
EOF
		[ $FORCE = "no" ] && read

	fi

	## Check for mysql connection in Postfix 
	if ! postconf -m | grep mysql >/dev/null; then
		echo "Error: Postfix does not have mysql support"
		return 1
	fi

	## Add user vmail	
	if getent passwd | grep -q $VMAIL_USER; then
		echo "Warning: User $VMAIL_USER already exists, continue? (Ctrl-c to abort)"
		[ $FORCE = "no" ] && read
	fi
	useradd -m $VMAIL_USER
	VMAIL_UID=$(getent passwd | grep $VMAIL_USER | awk -F':' '{print $3}')
	VMAIL_GID=$(getent passwd | grep $VMAIL_USER | awk -F':' '{print $4}')
	VMAIL_HOME=$(getent passwd | grep $VMAIL_USER | awk -F':' '{print $6}')

	return 0
}

install_pfadmin(){
	DEBIAN_PACKAGE_LOCATION='http://sourceforge.net/projects/postfixadmin/files/postfixadmin/postfixadmin-2.3.2/postfixadmin-2.3.2_all.deb/download'
	GENERIC_PACKAGE_LOCATION='http://sourceforge.net/projects/postfixadmin/files/postfixadmin/postfixadmin-2.3.2/postfixadmin-2.3.2.tar.gz/download'


	if [ $DISTRO = "debian" ]; then
		wget $DEBIAN_PACKAGE_LOCATION -O /root/postfixadmin.deb 
		PRESEEDTEMPFILE=$(mktemp)
		echo <<PRESEED >$PRESEEDTEMPFILE "
# PostgreSQL application password for postfixadmin:
postfixadmin	postfixadmin/pgsql/app-pass	password	
postfixadmin	postfixadmin/pgsql/admin-pass	password	
postfixadmin	postfixadmin/mysql/admin-pass	password	
postfixadmin	postfixadmin/app-password-confirm	password	
# MySQL application password for postfixadmin:
postfixadmin	postfixadmin/mysql/app-pass	password	
postfixadmin	postfixadmin/password-confirm	password	
# Host running the  server for postfixadmin:
postfixadmin	postfixadmin/remote/newhost	string	
# Connection method for PostgreSQL database of postfixadmin:
postfixadmin	postfixadmin/pgsql/method	select	unix socket
#  username for postfixadmin:
postfixadmin	postfixadmin/db/app-user	string	
# Do you want to purge the database for postfixadmin?
postfixadmin	postfixadmin/purge	boolean	false
# Error installing database for postfixadmin.  Retry?
postfixadmin	postfixadmin/install-error	select	abort
postfixadmin	postfixadmin/pgsql/no-empty-passwords	note	
# Re-install database for postfixadmin?
postfixadmin	postfixadmin/dbconfig-reinstall	boolean	false
postfixadmin	postfixadmin/reconfigure-webserver	multiselect	apache2
postfixadmin	postfixadmin/internal/skip-preseed	boolean	true
postfixadmin	postfixadmin/remote/port	string	
postfixadmin	postfixadmin/pgsql/changeconf	boolean	false
postfixadmin	postfixadmin/pgsql/admin-user	string	postgres
postfixadmin	postfixadmin/pgsql/authmethod-admin	select	ident
# Configure database for postfixadmin with dbconfig-common?
postfixadmin	postfixadmin/dbconfig-install	boolean	false
# Database type to be used by postfixadmin:
postfixadmin	postfixadmin/database-type	select	
postfixadmin	postfixadmin/internal/reconfiguring	boolean	false
# Perform upgrade on database for postfixadmin with dbconfig-common?
postfixadmin	postfixadmin/dbconfig-upgrade	boolean	true
# Host name of the  database server for postfixadmin:
postfixadmin	postfixadmin/remote/host	select	
# Error upgrading database for postfixadmin.  Retry?
postfixadmin	postfixadmin/upgrade-error	select	abort
# Connection method for MySQL database of postfixadmin:
postfixadmin	postfixadmin/mysql/method	select	unix socket
postfixadmin	postfixadmin/missing-db-package-error	select	abort
# Do you want to backup the database for postfixadmin before upgrading?
postfixadmin	postfixadmin/upgrade-backup	boolean	true
postfixadmin	postfixadmin/pgsql/authmethod-user	select	
postfixadmin	postfixadmin/mysql/admin-user	string	root
# Deconfigure database for postfixadmin with dbconfig-common?
postfixadmin	postfixadmin/dbconfig-remove	boolean	
# Error removing database for postfixadmin.  Retry?
postfixadmin	postfixadmin/remove-error	select	abort
#  storage directory for postfixadmin:
postfixadmin	postfixadmin/db/basepath	string	
postfixadmin	postfixadmin/pgsql/manualconf	note	
postfixadmin	postfixadmin/passwords-do-not-match	note	
#  database name for postfixadmin:
postfixadmin	postfixadmin/db/dbname	string	
"
PRESEED
		
		debconf-set-selections $PRESEEDTEMPFILE
 		rm -fr $PRESSEDTEMPFILE
		dpkg -i /root/postfixadmin.deb
	else
		wget $GENERIC_PACKAGE_LOCATION -O /root/postfixadmin.tar.gz
		tar -xvz -C /root -f /root/postfixadmin.tar.gz
		mkdir -p /var/www/html/
		cp -ra /root/postfixadmin-*/ /var/www/html/postfixadmin
	fi
	return 0
}

configure_pfa_database(){
	echo <<EOFMW "
#################################################################
#								
# $0 is about to create the mysql database for postfixadmin 
# called '$PFA_DB_DATABASE', and also will setup a mysql database
# user '$PFA_DB_USER'.
#
# Warning: if the database exists it will be droped, if the user
# exists the password will be reseted. (Ctrl-c to abort)
#
# Please provide the mysql root password
#################################################################
"	
EOFMW
	[ $FORCE = "no" ] && read	

	mysql -f -u root -p$MYSQL_ROOT_PASS -e <<EOSQL "DROP DATABASE IF EXISTS $PFA_DB_DATABASE ;
CREATE DATABASE $PFA_DB_DATABASE;
GRANT ALL PRIVILEGES ON $PFA_DB_DATABASE.* TO '$PFA_DB_USER'@'localhost' IDENTIFIED BY '$PFA_DB_PASS'; 
FLUSH PRIVILEGES;" 
EOSQL
	return 0
}

configure_pfadmin(){
	if [ $DISTRO = centos ]; then
		PFA_CONFIG=/var/www/html/postfixadmin/config.inc.php
	else
		PFA_CONFIG=/etc/postfixadmin/config.inc.php
	fi
	## Edits to make to postfixadmin config:
	#
        sed -i "s/.*\$CONF\['configured'\].*/\$CONF['configured'] = true;/g" $PFA_CONFIG
	sed -i "s/.*\$CONF\['database_type'\].*/\$CONF['database_type'] = 'mysql';/g" $PFA_CONFIG
        sed -i "s/.*\$CONF\['database_host'\].*/\$CONF['database_host'] = 'localhost';/g" $PFA_CONFIG
	sed -i "s/.*\$CONF\['database_user'\].*/\$CONF['database_user'] = '$PFA_DB_USER';/g"  $PFA_CONFIG
	sed -i "s/.*\$CONF\['database_password'\].*/\$CONF['database_password'] = '$PFA_DB_PASS';/g" $PFA_CONFIG
	sed -i "s/.*\$CONF\['database_name'\].*/\$CONF['database_name'] = '$PFA_DB_DATABASE';/g" $PFA_CONFIG
	sed -i "s/.*\$CONF\['setup_password'\].*/\$CONF['setup_password'] = '966c8e9257da5e17a81c47185f1f76c6:70e027e008662a559da763ce0eb2462e2a4d8f89';/g" $PFA_CONFIG	
	sed -i "s/.*\$CONF\['encrypt'\].*/\$CONF['encrypt'] = 'md5';/g" $PFA_CONFIG
	sed -i "s/.*\$CONF\['domain_path'\].*/\$CONF['domain_path'] = 'YES';/g" $PFA_CONFIG
	sed -i "s/.*\$CONF\['domain_in_mailbox'\].*/\$CONF['domain_in_mailbox'] = 'NO';/g" $PFA_CONFIG
	
	## TODO: IMPROVE . Restart apache
	if [ $DISTRO = "centos" ]; then
		/etc/init.d/httpd restart
	else
		/etc/init.d/apache2 restart
	fi 	

	## Populate DB 
	wget -q 'http://localhost/postfixadmin/setup.php' -O /dev/null
	return 0
}

add_pfa_admin_user(){	
	## Populate the admin
	mysql -u$PFA_DB_USER -p$PFA_DB_PASS $PFA_DB_DATABASE -e <<EOSQLA "INSERT INTO admin VALUES ('$PFA_ADMIN_USER',MD5('$PFA_ADMIN_PASS'),'2011-01-15 04:08:27','2011-01-15 04:08:27',1);
INSERT INTO domain_admins VALUES ('$PFA_ADMIN_USER','ALL','2011-01-15 04:08:27',1);"
EOSQLA
}

configure_dovecot(){
	DOVECOT_AUTH_SOCKET=/var/spool/postfix/private/auth

	if [ $DISTRO = debian ]; then
		DOVECOT_CONFIG=/etc/dovecot/dovecot.conf
		DOVECOT_MYSQL_CONFIG=/etc/dovecot/dovecot-mysql.conf
	else
		DOVECOT_CONFIG=/etc/dovecot.conf
		DOVECOT_MYSQL_CONFIG=/etc/dovecot-mysql.conf
	fi

	## Make backup if this is the first time, do not overwrite in further runs
	if ! [ -f $DOVECOT_CONFIG.prepostfixadminbackup ]; then
		cp $DOVECOT_CONFIG $DOVECOT_CONFIG.prepostfixadminbackup
		echo "Dovecot configuration backup saved at: $DOVECOT_CONFIG.prepostfixadminbackup"
	fi
	
	[ -e $DOVECOT_MYSQL_CONFIG ] && echo "Warning: Overwrite $DOVECOT_MYSQL_CONFIG? (Ctrl-c to abort)" && [ $FORCE = "no" ] && read
	
	echo <<DOVECOTMYSQL >$DOVECOT_MYSQL_CONFIG " 

connect = host=localhost dbname=$PFA_DB_DATABASE user=$PFA_DB_USER password=$PFA_DB_PASS
driver = mysql

default_pass_scheme = PLAIN-MD5

# Query to retrieve password. user can be used to retrieve username in other
# formats also.

password_query = SELECT username AS user,password FROM mailbox WHERE username = '%u' AND active='1'

# Query to retrieve user information.

"
DOVECOTMYSQL

	if dovecot --version | grep -q '^1\.2.*'; then
		echo "user_query = SELECT CONCAT('/home/vmail/', maildir) AS home, $VMAIL_UID AS uid, $VMAIL_GID AS gid, CONCAT('*:bytes=', quota) AS quota_rule FROM mailbox WHERE username = '%u' AND active='1'" >>$DOVECOT_MYSQL_CONFIG
	else
		echo "user_query = SELECT maildir AS home, $VMAIL_UID AS uid, $VMAIL_GID AS gid FROM mailbox WHERE username = '%u' AND active='1'" >>$DOVECOT_MYSQL_CONFIG
	fi

	if grep -q '^ *[^#]\+userdb *sql *{\|^ *[^#]\+passdb *sql *{' $DOVECOT_CONFIG; then
		echo "Warning: Dovecot configuration already contains overlapping 'auth default' configuration, not proceeding with the rest of the dovecot configuration "
		[ $FORCE = "no" ] && read
		## 
		return 1
	fi

	sed -i -e 's/^ *[^#]\+mechanisms\(.*\)/#mechanisms\1/g' $DOVECOT_CONFIG

	## Create temp file with the configuration
	TEMPFILE=$(mktemp)

	echo <<DOVECOT_TMP_CONFIG >$TEMPFILE '###### POSTFIXADMIN ADDED CONFIGURATION #####
    mechanisms = plain 
    userdb sql {
      # Path for SQL configuration file, see doc/dovecot-sql-example.conf
      args = '$DOVECOT_MYSQL_CONFIG'
    }
    passdb sql {
      # Path for SQL configuration file, see doc/dovecot-sql-example.conf
      args = '$DOVECOT_MYSQL_CONFIG'
    }
###### POSTFIXADMIN ADDED CONFIGURATION #####
'
DOVECOT_TMP_CONFIG

	if ! grep -q '^ *[^#]\+socket *listen *{' $DOVECOT_CONFIG; then
		echo <<DOVECOT_TMP_CONFIG >>$TEMPFILE '
    socket listen {
      client {
        path = '$DOVECOT_AUTH_SOCKET'
        mode = 0660
        user = postfix
        group = postfix
      }
    }
###### POSTFIXADMIN ADDED CONFIGURATION #####
'
DOVECOT_TMP_CONFIG
	fi

	## Insert the configuration in dovecot in correct place with contents of the tempfile
	sed -i -e 's/^\( *auth default *{\)/\1\n#INSERTPFACONFIGHERE/g' $DOVECOT_CONFIG

	sed -i -e "/#INSERTPFACONFIGHERE/r $TEMPFILE" -e "/#INSERTPFACONFIGHERE/d" $DOVECOT_CONFIG

	## Remove temp file
	rm -fr $TEMPFILE

	## General configuration chages
	sed -i -e 's/^\([ #]*mail_location.*\)/#\1/g' $DOVECOT_CONFIG	
	echo "mail_location =  maildir:$VMAIL_HOME/%d/%n" >> $DOVECOT_CONFIG	

	sed -i -e 's/^\([ #]*disable_plaintext_auth.*\)/#\1/g' $DOVECOT_CONFIG
	echo "disable_plaintext_auth = no" >> $DOVECOT_CONFIG

	## Enable pop3 / imap at least
	if grep -q '^[ #]*protocols *= *none$' $DOVECOT_CONFIG; then
		sed -i -e 's/^\([ #]*protocols.*\)/#\1/g' $DOVECOT_CONFIG
		echo "protocols = imap pop3" >>$DOVECOT_CONFIG
	fi

	## TODO IMPROVE
	/etc/init.d/dovecot restart
	restart dovecot

	return 0
}

configure_postfix(){
	POSTFIX_MAIN_CONFIG=/etc/postfix/main.cf
	
	MYSQL_VIRTUAL_ALIAS_MAPS=/etc/postfix/mysql_virtual_alias_maps.cf
	MYSQL_VIRTUAL_ALIAS_DOMIANS_MAPS=/etc/postfix/mysql_virtual_alias_domain_maps.cf
	MYSQL_VIRTUAL_ALIAS_DOMAIN_CATCHALL_MAPS=/etc/postfix/mysql_virtual_alias_domain_catchall_maps.cf
	MYSQL_VIRTUAL_DOMAINS_MAPS=/etc/postfix/mysql_virtual_domains_maps.cf
	MYSQL_VIRTUAL_MAILBOX_MAPS=/etc/postfix/mysql_virtual_mailbox_maps.cf
	MYSQL_VIRTUAL_ALIAS_DOMAIN_MAILBOX_MAPS=/etc/postfix/mysql_virtual_alias_domain_mailbox_maps.cf

	## Make backup if this is the first time, do not overwrite in further runs
	if ! [ -f $POSTFIX_MAIN_CONFIG.prepostfixadminbackup ]; then
		cp $POSTFIX_MAIN_CONFIG $POSTFIX_MAIN_CONFIG.prepostfixadminbackup
	fi

	## Write postfix mysql files	
	[ -e $MYSQL_VIRTUAL_ALIAS_MAPS  ] && echo "Warning: Overwrite $MYSQL_VIRTUAL_ALIAS_MAPS? (Ctrl-c to abort)" && [ $FORCE = "no" ] && read
	echo <<PMVAM >$MYSQL_VIRTUAL_ALIAS_MAPS "
user = $PFA_DB_USER
password = $PFA_DB_PASS
hosts = 127.0.0.1
dbname = $PFA_DB_DATABASE
query = SELECT goto FROM alias WHERE address='%s' AND active = '1'
#expansion_limit = 100
"
PMVAM

	[ -e $MYSQL_VIRTUAL_ALIAS_DOMIANS_MAPS  ] && echo "Warning: Overwrite $MYSQL_VIRTUAL_ALIAS_DOMIANS_MAPS? (Ctrl-c to abort)" && [ $FORCE = "no" ] && read
	echo <<PMVADM >$MYSQL_VIRTUAL_ALIAS_DOMIANS_MAPS "
user = $PFA_DB_USER
password = $PFA_DB_PASS
hosts = 127.0.0.1
dbname = $PFA_DB_DATABASE
query = SELECT goto FROM alias,alias_domain WHERE alias_domain.alias_domain = '%d' and alias.address = CONCAT('%u', '@', alias_domain.target_domain) AND alias.active = 1 AND alias_domain.active='1'
"
PMVADM

	[ -e $MYSQL_VIRTUAL_ALIAS_DOMAIN_CATCHALL_MAPS ] && echo "Warning: Overwrite $MYSQL_VIRTUAL_ALIAS_DOMAIN_CATCHALL_MAPS? (Ctrl-c to abort)" && [ $FORCE = "no" ] && read
	echo <<PMVADCM >$MYSQL_VIRTUAL_ALIAS_DOMAIN_CATCHALL_MAPS "
# handles catch-all settings of target-domain
user = $PFA_DB_USER
password = $PFA_DB_PASS
hosts = 127.0.0.1
dbname = $PFA_DB_DATABASE
query  = SELECT goto FROM alias,alias_domain WHERE alias_domain.alias_domain = '%d' and alias.address = CONCAT('@', alias_domain.target_domain) AND alias.active = 1 AND alias_domain.active='1'
"
PMVADCM

	[ -e $MYSQL_VIRTUAL_DOMAINS_MAPS ] && echo "Warning: Overwrite $MYSQL_VIRTUAL_DOMAINS_MAPS? (Ctrl-c to abort)" && [ $FORCE = "no" ] && read
	echo <<PMVDM >$MYSQL_VIRTUAL_DOMAINS_MAPS "
user = $PFA_DB_USER
password = $PFA_DB_PASS
hosts = 127.0.0.1
dbname = $PFA_DB_DATABASE
query          = SELECT domain FROM domain WHERE domain='%s' AND active = '1'
#query          = SELECT domain FROM domain WHERE domain='%s'
#optional query to use when relaying for backup MX
#query           = SELECT domain FROM domain WHERE domain='%s' AND backupmx = '0' AND active = '1'
#expansion_limit = 100
"
PMVDM
	
	[ -e $MYSQL_VIRTUAL_MAILBOX_MAPS ] && echo "Warning: Overwrite $MYSQL_VIRTUAL_MAILBOX_MAPS? (Ctrl-c to abort)" && [ $FORCE = "no" ] && read
	echo <<PMVMP >$MYSQL_VIRTUAL_MAILBOX_MAPS "
user = $PFA_DB_USER
password = $PFA_DB_PASS
hosts = 127.0.0.1
dbname = $PFA_DB_DATABASE
query           = SELECT maildir FROM mailbox WHERE username='%s' AND active = '1'
#expansion_limit = 100

"
PMVMP
	
	[ -e $MYSQL_VIRTUAL_ALIAS_DOMAIN_MAILBOX_MAPS ] && echo "Warning: Overwrite $MYSQL_VIRTUAL_ALIAS_DOMAIN_MAILBOX_MAPS? (Ctrl-c to abort)" && [ $FORCE = "no" ] && read

	echo <<PMVADMM >$MYSQL_VIRTUAL_ALIAS_DOMAIN_MAILBOX_MAPS "
user = $PFA_DB_USER
password = $PFA_DB_PASS
hosts = 127.0.0.1
dbname = $PFA_DB_DATABASE
query = SELECT maildir FROM mailbox,alias_domain WHERE alias_domain.alias_domain = '%d' and mailbox.username = CONCAT('%u', '@', alias_domain.target_domain) AND mailbox.active = 1 AND alias_domain.active='1'

"
PMVADMM
	
	## Postconf postfixadmin mysql configuration
	postconf -e "virtual_mailbox_domains = proxy:mysql:$MYSQL_VIRTUAL_DOMAINS_MAPS"
	postconf -e "virtual_alias_maps =  proxy:mysql:$MYSQL_VIRTUAL_ALIAS_MAPS, proxy:mysql:$MYSQL_VIRTUAL_ALIAS_DOMIANS_MAPS, proxy:mysql:$MYSQL_VIRTUAL_ALIAS_DOMAIN_CATCHALL_MAPS"
	postconf -e "virtual_mailbox_maps = proxy:mysql:$MYSQL_VIRTUAL_MAILBOX_MAPS, proxy:mysql:$MYSQL_VIRTUAL_ALIAS_DOMAIN_MAILBOX_MAPS"
	postconf -e "virtual_mailbox_base = $VMAIL_HOME"
	postconf -e "virtual_uid_maps = static:$VMAIL_UID"
	postconf -e "virtual_gid_maps = static:$VMAIL_UID"
	postconf -e "virtual_minimum_uid = $VMAIL_UID"
	postconf -e "virtual_transport = virtual"

	## Postconf dovecot sasl configuraion
	postconf -e "broken_sasl_auth_clients = yes" 
	postconf -e "smtpd_recipient_restrictions = permit_mynetworks, permit_sasl_authenticated, reject_non_fqdn_hostname, reject_non_fqdn_sender, reject_non_fqdn_recipient, reject_unauth_destination, reject_unauth_pipelining, reject_invalid_hostname"
	postconf -e "smtpd_sasl_auth_enable = yes"
	postconf -e "smtpd_sasl_type = dovecot"
	postconf -e "smtpd_sasl_path = private/auth"

	## Special cases
	if [ $DISTRO = "centos" ]; then
		postconf -e "inet_interfaces = all"
	fi
	
	## TODO: IMPROVE Restart postfix 
	/etc/init.d/postfix restart
	restart postfix

	return 0
}


set_global_default_env

usage(){
	echo <<USAGE "
Usage: $(basename $0) [OPTION...]

$(basename $0) will attempt to install all configurations for postfixadmin by default,
assumes that the current postfix and dovecot configurations are the base ones in 
Debian/Centos/Ubuntu. It will use default settings for usernames and database names. 
It will generate random passwords and the relevant ones will be informed. 

Options:
 -a <email>	email address to used as admin user in postfixadmin. DEFAULT: $PFA_ADMIN_USER
 -p <password>	password to be setup for the admin user in postixadmin. DEFAULT: RANDOM
 -j <dbuser>	mysql database username to be setup. DEFAULT: $PFA_DB_USER
 -k <dbpass>	password to be assigned to the mysql database user. DEFAULT: RANDOM
 -d <dbname>	mysql Database name. DEFAULT: $PFA_DB_DATABASE
 -v <user>	name of the unix user that will hold the mailboxes. DEFAULT: $VMAIL_USER
 -f		force the install, prompts in error/warnings are disabled.
 -h		this Help

Advanced Options:
 -t <task1,task2>	Comma separated of tasks to execute manually, may depend on the above 
			options. DEFAULT: all
 Possible Tasks:
   install_deps			installs postfixadmin dependencies
   install_pfadmin		downloads and installs postfixadmin package
   configure_pfa_database	configures postfixadmin database
   configure_pfadmin		configures postfixadmin
   add_pfa_admin_user		adds admin user to postfixadmin
   configure_dovecot		configures dovecot
   configure_postfix		configures postfix
"
USAGE
}



## Parse args and execute tasks
while getopts 'a:p:j:k:d:v:t:fh' option; do
	case $option in
	a)	PFA_ADMIN_USER=$OPTARG;;
	p)	PFA_ADMIN_PASS=$OPTARG;;
	j)	PFA_DB_USER=$OPTARG;;
	k)	PFA_DB_PASS=$OPTARG;;
	d)	PFA_DB_DATABASE=$OPTARG;;
	v)	VMAIL_USER=$OPTARG;;
	t)	TASKS=$OPTARG;;
	f)	FORCE="yes";;
	h)	usage
		exit 0;;
	[?])	usage
		exit 1;;	
    esac
done
shift $(($OPTIND - 1))

if [ $TASKS = "all" ]; then
	echo <<EOF "
$(basename $0) will attempt to install all configurations for postfixadmin by default,
assumes that the current postfix and dovecot configurations are the base ones in 
Debian/Centos/Ubuntu. It will use default settings for usernames and database names. 
It will generate random passwords and the relevant ones will be informed. 
"
EOF
	[ $FORCE = "no" ] && read	
	
	install_deps
	[ $? -ne "0" ] && exit 1
	install_pfadmin
	[ $? -ne "0" ] && exit 1
	configure_pfa_database	
	[ $? -ne "0" ] && exit 1
	configure_pfadmin
	[ $? -ne "0" ] && exit 1
	add_pfa_admin_user
	[ $? -ne "0" ] && exit 1
	configure_dovecot
#	[ $? -ne "0" ] && exit 1
	configure_postfix
	[ $? -ne "0" ] && exit 1
	
	echo <<EOF "
#################################################################
#								
# Assigned Postfixadmin Admin username: $PFA_ADMIN_USER	
# Assigned Postfixadmin Admin password: $PFA_ADMIN_PASS
#
#################################################################
"	
EOF

else
	## Detect missing vars
	VMAIL_UID=$(getent passwd | grep $VMAIL_USER | awk -F':' '{print $3}')
	VMAIL_GID=$(getent passwd | grep $VMAIL_USER | awk -F':' '{print $4}')
	VMAIL_HOME=$(getent passwd | grep $VMAIL_USER | awk -F':' '{print $6}')

	echo <<EOF "
#################################################################
#         
# Using the following enviroment:
#                                                      
# Postfixadmin Admin username: $PFA_ADMIN_USER 
# Postfixadmin Admin password: $PFA_ADMIN_PASS 
# Postfixadmin Mysql username: $PFA_DB_USER
# Postfixadmin Mysql password: $PFA_DB_PASS
# Postfixadmin Mysql database: $PFA_DB_DATABASE
# Vmail user: $VMAIL_USER
# Vmail uid: $VMAIL_UID
# Vmail gid: $VMAIL_GID
# Vmail home: $VMAIL_HOME
#################################################################
"
EOF
	for t in $( echo $TASKS | tr ',' ' '); do
		$t
	done
fi

exit 0

