#!/bin/bash

# Copyright Rimuhosting.com

# script to install postfix configs for postfixadmin
# shaded toward debian
#
# TODO: package dependency and install requirements
#

## Detect distro version
if [ -e /etc/debian_version ]; then
	if ! grep -q '6\..' /etc/debian_version; then
		echo "Error: Script supports only debian 6.X squeeze"
		exit 1
	fi
else
	echo "Error: Not a debian system"
	exit 1
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

	## Database credentials for roundcube
	RC_DB_PASS=$(</dev/urandom tr -dc A-Za-z0-9 | head -c8)
	RC_DB_USER="roundcube"
	RC_DB_DATABASE="roundcube"	

	# Task to perform
	TASKS="all"
	FORCE="no"

}

install_deps(){

	## Update package cache database
	apt-get update

	## Install required packages and configure global enviroment	
	MYSQL_INSTALL_SCRIPT_URL='http://proj.ri.mu/installmysql.sh'

	wget $MYSQL_INSTALL_SCRIPT_URL -O /root/installmysql.sh

	if [ $FORCE = "no" ]; then
		bash /root/installmysql.sh --noperl --noapache --nophp
		export MYSQL_ROOT_PASS=$(cat /root/.mysqlp)
	else
		bash /root/installmysql.sh --noprompt --adminpass $MYSQL_ROOT_PASS --noperl --noapache --nophp
	fi

	## Specific distribution packages
	export DEBIAN_FRONTEND=noninteractive
	apt-get -y install postfix-mysql php5-imap php5-mysql wwwconfig-common dbconfig-common dovecot-imapd dovecot-pop3d spamassassin



	if dpkg -l | grep -q sasl2-bin; then
		apt-get -y --purge remove sasl2-bin
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
	VMAIL_UID=$(getent passwd | grep '^'$VMAIL_USER':' | awk -F':' '{print $3}')
	VMAIL_GID=$(getent passwd | grep '^'$VMAIL_USER':' | awk -F':' '{print $4}')
	VMAIL_HOME=$(getent passwd | grep '^'$VMAIL_USER':' | awk -F':' '{print $6}')

}

install_pfadmin(){
	DEBIAN_PACKAGE_LOCATION='http://iweb.dl.sourceforge.net/project/postfixadmin/postfixadmin/postfixadmin-2.3.5/postfixadmin_2.3.5-1_all.deb'

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
}

configure_pfa_database(){
	echo <<EOFMW "
#################################################################
#								
# $0 is about to create the mysql database for postfixadmin 
# called '$PFA_DB_DATABASE', and also will setup a mysql database
# user '$PFA_DB_USER'.
#
# Warning: if the database exists it will be dropped, if the user
# exists the password will be reset. (Ctrl-c to abort)
#
# Please provide the mysql root password if required
#################################################################
"	
EOFMW
	[ $FORCE = "no" ] && read	

	mysql -f -u root -p$MYSQL_ROOT_PASS -e <<EOSQL "DROP DATABASE IF EXISTS $PFA_DB_DATABASE ;
CREATE DATABASE $PFA_DB_DATABASE;
GRANT ALL PRIVILEGES ON $PFA_DB_DATABASE.* TO '$PFA_DB_USER'@'localhost' IDENTIFIED BY '$PFA_DB_PASS'; 
FLUSH PRIVILEGES;" 
EOSQL
}

configure_pfadmin(){
	PFA_CONFIG=/etc/postfixadmin/config.inc.php

	## Make backup if this is the first time, do not overwrite in further runs
        if ! [ -f $PFA_CONFIG.prepostfixadminbackup ]; then
                cp $PFA_CONFIG $PFA_CONFIG.prepostfixadminbackup
                echo "Postfixadmin configuration backup saved at: $PFA_CONFIG.prepostfixadminbackup"
        fi

	## Edits to make to postfixadmin config:
	#
	sed -i "s/^\$CONF\['configured'\].*/\$CONF['configured'] = true;/g" $PFA_CONFIG
	sed -i "s/^\$CONF\['database_type'\].*/\$CONF['database_type'] = 'mysql';/g" $PFA_CONFIG
	sed -i "s/^\$CONF\['database_host'\].*/\$CONF['database_host'] = 'localhost';/g" $PFA_CONFIG
	sed -i "s/^\$CONF\['database_user'\].*/\$CONF['database_user'] = '$PFA_DB_USER';/g"  $PFA_CONFIG
	sed -i "s/^\$CONF\['database_password'\].*/\$CONF['database_password'] = '$PFA_DB_PASS';/g" $PFA_CONFIG
	sed -i "s/^\$CONF\['database_name'\].*/\$CONF['database_name'] = '$PFA_DB_DATABASE';/g" $PFA_CONFIG
	sed -i "s/^\$CONF\['setup_password'\].*/\$CONF['setup_password'] = '966c8e9257da5e17a81c47185f1f76c6:70e027e008662a559da763ce0eb2462e2a4d8f89';/g" $PFA_CONFIG	
	sed -i "s/^\$CONF\['encrypt'\].*/\$CONF['encrypt'] = 'md5';/g" $PFA_CONFIG
	sed -i "s/^\$CONF\['domain_path'\].*/\$CONF['domain_path'] = 'YES';/g" $PFA_CONFIG
	sed -i "s/^\$CONF\['domain_in_mailbox'\].*/\$CONF['domain_in_mailbox'] = 'NO';/g" $PFA_CONFIG
	sed -i "s/^\$CONF\['fetchmail'\].*/\$CONF['fetchmail'] = 'NO';/g" $PFA_CONFIG
	sed -i "s/^\$CONF\['sendmail'\].*/\$CONF['sendmail'] = 'NO';/g" $PFA_CONFIG
	sed -i "s/\$CONF\['backup'\].*/\$CONF['backup'] = 'NO';/g" $PFA_CONFIG
	#Dirty, but it is a bug in postfixadmin
	IP_ADDRESS=$(ifconfig eth0 | grep 'inet addr:' | sed 's/.*inet addr:\([0-9.]*\) .*/\1/g' )
	sed -i "s/^\$CONF\['postfix_admin_url'\].*/\$CONF['postfix_admin_url'] = 'http:\/\/$IP_ADDRESS\/postfixadmin';/g" $PFA_CONFIG

	
	/etc/init.d/apache2 restart

	## Sanity check Apache is running 
	TESTAPACHE=$(netstat -lnp | grep :80 | awk -F" " '{print $7}' | awk -F\/ '{print $2}')
	if [ "$TESTAPACHE" != "apache2" ]; then
			echo "Error: Apache2 is not listening on port 80.  You will need to run setup.php again."
	fi

	## Populate DB 
	
	wget -q 'http://localhost/postfixadmin/setup.php' -O /dev/null
}

add_pfa_admin_user(){	
	## Populate the admin
	mysql -u$PFA_DB_USER -p$PFA_DB_PASS $PFA_DB_DATABASE -e <<EOSQLA "INSERT INTO admin VALUES ('$PFA_ADMIN_USER',MD5('$PFA_ADMIN_PASS'),'2011-01-15 04:08:27','2011-01-15 04:08:27',1);
INSERT INTO domain_admins VALUES ('$PFA_ADMIN_USER','ALL','2011-01-15 04:08:27',1);"
EOSQLA
}

configure_dovecot(){
	DOVECOT_AUTH_SOCKET_POSTFIX=/var/spool/postfix/private/auth
	DOVECOT_AUTH_SOCKET_LDA=/var/run/dovecot/auth-master
	DOVECOT_CONFIG=/etc/dovecot/dovecot.conf
	DOVECOT_MYSQL_CONFIG=/etc/dovecot/dovecot-mysql.conf
	DOVECOT_DEFAULT_SIEVE=/etc/dovecot/default.sieve
	
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
user_query = SELECT CONCAT('/home/vmail/', maildir) AS home, $VMAIL_UID AS uid, $VMAIL_GID AS gid, CONCAT('*:bytes=', quota) AS quota_rule FROM mailbox WHERE username = '%u' AND active='1'
"
DOVECOTMYSQL

	if grep -q '^ *[^#]\+socket *listen *{\|^ *[^#]\+userdb *sql *{\|^ *[^#]\+passdb *sql *{' $DOVECOT_CONFIG; then
		echo "Warning: Dovecot configuration already contains overlapping 'auth default', overwrite ? (Ctrl-c to abort)"
		[ $FORCE = "no" ] && read
	fi

	[ -e $DOVECOT_DEFAULT_SIEVE ] && echo "Warning: Overwrite $DOVECOT_DEFAULT_SIEVE? (Ctrl-c to abort)" && [ $FORCE = "no" ] && read		
	echo <<DOVECOTDEFAULTSIEVE >$DOVECOT_DEFAULT_SIEVE '
require "fileinto";
if header :contains "X-Spam-Flag" "YES" {
  fileinto "Junk";
}
'
DOVECOTDEFAULTSIEVE


	echo <<DOVECOTCONF  >$DOVECOT_CONFIG "
protocols = imap pop3 imaps pop3s managesieve
log_timestamp = "%Y-%m-%d %H:%M:%S "
mail_privileged_group = mail
mail_location =  maildir:~/.Maildir
ssl = yes
ssl_cert_file = /etc/ssl/certs/dovecot.pem
ssl_key_file = /etc/ssl/private/dovecot.pem

protocol imap {
}
  
protocol pop3 {
  pop3_uidl_format = %08Xu%08Xv
}

protocol managesieve {
}

protocol lda {
  postmaster_address = $PFA_ADMIN_USER
  auth_socket_path = /var/run/dovecot/auth-master
  mail_plugins = sieve
}

disable_plaintext_auth = no

auth default {
  mechanisms = plain login 
  user = root
  passdb pam {
  }
  userdb passwd {
  }
  userdb sql {
    args = $DOVECOT_MYSQL_CONFIG
  }
  passdb sql {
    args = $DOVECOT_MYSQL_CONFIG
  }
  socket listen {
    client {
      path = $DOVECOT_AUTH_SOCKET_POSTFIX
      mode = 0660
      user = postfix
      group = postfix
    }
    master {
      path = $DOVECOT_AUTH_SOCKET_LDA
      mode = 0600
      user = $VMAIL_USER 
    }
  }
}

dict {
}

plugin {
  sieve = ~/.dovecot.sieve
  sieve_dir = ~/.sieve
  sieve_global_path = $DOVECOT_DEFAULT_SIEVE
  sieve_global_dir = /etc/dovecot/sieve
}

"
DOVECOTCONF
	sievec $DOVECOT_DEFAULT_SIEVE
	/etc/init.d/dovecot restart
	update-rc.d dovecot defaults

}

configure_spamassassin(){
	SA_DEFAULT_INIT_CONFIG=/etc/default/spamassassin
	## Make backup if this is the first time, do not overwrite in further runs
        if ! [ -f $SA_DEFAULT_INIT_CONFIG.prepostfixadminbackup ]; then
                cp $SA_DEFAULT_INIT_CONFIG $SA_DEFAULT_INIT_CONFIG.prepostfixadminbackup
                echo "Spamassassin default init configuration backup saved at: $SA_DEFAULT_INIT_CONFIG.prepostfixadminbackup"
        fi

	sed -i 's/^ENABLED=0/ENABLED=1/g' $SA_DEFAULT_INIT_CONFIG
	/etc/init.d/spamassassin restart

	# IMPROVE: maybe setup cron for sa-learn
}


configure_postfix(){
	POSTFIX_MAIN_CONFIG=/etc/postfix/main.cf
	POSTFIX_MASTER_CONFIG=/etc/postfix/master.cf
	
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

	if ! [ -f $POSTFIX_MASTER_CONFIG.prepostfixadminbackup ]; then
		cp $POSTFIX_MASTER_CONFIG $POSTFIX_MASTER_CONFIG.prepostfixadminbackup
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
	echo <<PMVMM >$MYSQL_VIRTUAL_MAILBOX_MAPS "
user = $PFA_DB_USER 
password = $PFA_DB_PASS 
hosts = 127.0.0.1
dbname = $PFA_DB_DATABASE
query           = SELECT maildir FROM mailbox WHERE username='%s' AND active = '1'
"
PMVMM

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
	postconf -e "virtual_transport = dovecot"
	postconf -e "mailbox_command = /usr/lib/dovecot/deliver"
	## Postconf dovecot sasl configuraion
	postconf -e "broken_sasl_auth_clients = yes" 
	postconf -e "smtpd_recipient_restrictions = permit_mynetworks, permit_sasl_authenticated, reject_unauth_destination"
	postconf -e "smtpd_sasl_auth_enable = yes"
	postconf -e "smtpd_sasl_type = dovecot"
	postconf -e "smtpd_sasl_path = private/auth"
	postconf -e "mydestination = localhost"
	postconf -e "dovecot_destination_recipient_limit = 1"
	postconf -e "inet_interfaces = all"


	grep -q 'spamassassin\|dovecot' $POSTFIX_MASTER_CONFIG && echo "Warning: $POSTFIX_MASTER_CONFIG already contains onfigurations, continue? (Ctrl-c to abort)"  && [ $FORCE = "no" ] && read

	sed -i 's/^\(smtp *inet.*\)/#\1/g' $POSTFIX_MASTER_CONFIG
	
echo <<POSTFIXMASTER >>$POSTFIX_MASTER_CONFIG '
smtp      inet  n       -       -       -       -       smtpd
	-o content_filter=spamassassin

spamassassin unix  -       n       n       -       -       pipe
   user=nobody argv=/usr/bin/spamc -f -e /usr/sbin/sendmail -oi -f ${sender} ${recipient}

dovecot   unix  -       n       n       -       -       pipe
  flags=DRhu user=vmail:vmail argv=/usr/lib/dovecot/deliver -f ${sender} -d ${recipient}
'
POSTFIXMASTER

	/etc/init.d/postfix restart
}


install_roundcube(){

	PRESEEDTEMPFILE=$(mktemp)
	echo <<ROUNDCUBE_CORE_PRESEED >$PRESEEDTEMPFILE "
roundcube-core	roundcube/password-confirm	password	
roundcube-core	roundcube/mysql/admin-pass	password	
# MySQL application password for roundcube:
roundcube-core	roundcube/mysql/app-pass	password	
roundcube-core	roundcube/app-password-confirm	password	
# PostgreSQL application password for roundcube:
roundcube-core	roundcube/pgsql/app-pass	password	
roundcube-core	roundcube/pgsql/admin-pass	password	
# Reinstall database for roundcube?
roundcube-core	roundcube/dbconfig-reinstall	boolean	false
# Connection method for MySQL database of roundcube:
roundcube-core	roundcube/mysql/method	select	unix socket
roundcube-core	roundcube/upgrade-error	select	abort
roundcube-core	roundcube/pgsql/authmethod-user	select	password
# Do you want to purge the database for roundcube?
roundcube-core	roundcube/purge	boolean	false
# Configure database for roundcube with dbconfig-common?
roundcube-core	roundcube/dbconfig-install	boolean	false
#  database name for roundcube:
roundcube-core	roundcube/db/dbname	string	
roundcube-core	roundcube/language	select	en_US
roundcube-core	roundcube/remove-error	select	abort
# Host running the  server for roundcube:
roundcube-core	roundcube/remote/newhost	string	
roundcube-core	roundcube/pgsql/changeconf	boolean	false
roundcube-core	roundcube/restart-webserver	boolean	true
# Do you want to back up the database for roundcube before upgrading?
roundcube-core	roundcube/upgrade-backup	boolean	true
# Perform upgrade on database for roundcube with dbconfig-common?
roundcube-core	roundcube/dbconfig-upgrade	boolean	false
roundcube-core	roundcube/install-error	select	abort
roundcube-core	roundcube/remote/port	string	
roundcube-core	roundcube/mysql/admin-user	string	root
# Connection method for PostgreSQL database of roundcube:
roundcube-core	roundcube/pgsql/method	select	unix socket
roundcube-core	roundcube/pgsql/manualconf	note	
roundcube-core	roundcube/hosts	string	localhost
#  storage directory for roundcube:
roundcube-core	roundcube/db/basepath	string	
roundcube-core	roundcube/pgsql/authmethod-admin	select	ident
# Deconfigure database for roundcube with dbconfig-common?
roundcube-core	roundcube/dbconfig-remove	boolean	
#roundcube-core	roundcube/pgsql/no-empty-passwords	error	
roundcube-core	roundcube/pgsql/admin-user	string	postgres
#roundcube-core	roundcube/passwords-do-not-match	error	
roundcube-core	roundcube/internal/reconfiguring	boolean	true
roundcube-core	roundcube/reconfigure-webserver	multiselect	apache2
# Database type to be used by roundcube:
roundcube-core	roundcube/database-type	select	
# Host name of the  database server for roundcube:
roundcube-core	roundcube/remote/host	select	
roundcube-core	roundcube/internal/skip-preseed	boolean	true
#  username for roundcube:
roundcube-core	roundcube/db/app-user	string	
roundcube-core	roundcube/missing-db-package-error	select	abort

"
ROUNDCUBE_CORE_PRESEED

	debconf-set-selections $PRESEEDTEMPFILE
	rm -fr $PRESEEDTEMPFILE
	apt-get -y install roundcube roundcube-core roundcube-mysql

}

configure_roundcube(){
	## Configure roundcube database
	echo <<EOFMW "
#################################################################
#
# $0 is about to create the mysql database for roundcube
# called '$RC_DB_DATABASE', and also will setup a mysql database
# user '$RC_DB_USER'.
#
# Warning: if the database exists it will be dropped, if the user
# exists the password will be reset. (Ctrl-c to abort)
#
# Please provide the mysql root password if required
#################################################################
"
EOFMW
        [ $FORCE = "no" ] && read

        mysql -f -u root -p$MYSQL_ROOT_PASS -e <<EOSQL "DROP DATABASE IF EXISTS $RC_DB_DATABASE ;
CREATE DATABASE $RC_DB_DATABASE;
GRANT ALL PRIVILEGES ON $RC_DB_DATABASE.* TO '$RC_DB_USER'@'localhost' IDENTIFIED BY '$RC_DB_PASS';
FLUSH PRIVILEGES;"
EOSQL


	## Populate roundcube database

	ROUNDCUBE_MYSQL_INITIAL_TEMP=$(mktemp)
	echo <<EOSQLR >$ROUNDCUBE_MYSQL_INITIAL_TEMP "

/*!40014  SET FOREIGN_KEY_CHECKS=0 */;

-- Table structure for table \`session\`

CREATE TABLE \`session\` (
 \`sess_id\` varchar(40) NOT NULL,
 \`created\` datetime NOT NULL DEFAULT '1000-01-01 00:00:00',
 \`changed\` datetime NOT NULL DEFAULT '1000-01-01 00:00:00',
 \`ip\` varchar(40) NOT NULL,
 \`vars\` mediumtext NOT NULL,
 PRIMARY KEY(\`sess_id\`),
 INDEX \`changed_index\` (\`changed\`)
) /*!40000 ENGINE=INNODB */ /*!40101 CHARACTER SET utf8 COLLATE utf8_general_ci */;


-- Table structure for table \`users\`

CREATE TABLE \`users\` (
 \`user_id\` int(10) UNSIGNED NOT NULL AUTO_INCREMENT,
 \`username\` varchar(128) NOT NULL,
 \`mail_host\` varchar(128) NOT NULL,
 \`alias\` varchar(128) NOT NULL,
 \`created\` datetime NOT NULL DEFAULT '1000-01-01 00:00:00',
 \`last_login\` datetime NOT NULL DEFAULT '1000-01-01 00:00:00',
 \`language\` varchar(5),
 \`preferences\` text,
 PRIMARY KEY(\`user_id\`),
 INDEX \`username_index\` (\`username\`),
 INDEX \`alias_index\` (\`alias\`)
) /*!40000 ENGINE=INNODB */ /*!40101 CHARACTER SET utf8 COLLATE utf8_general_ci */;


-- Table structure for table \`messages\`

CREATE TABLE \`messages\` (
 \`message_id\` int(11) UNSIGNED NOT NULL AUTO_INCREMENT,
 \`user_id\` int(10) UNSIGNED NOT NULL DEFAULT '0',
 \`del\` tinyint(1) NOT NULL DEFAULT '0',
 \`cache_key\` varchar(128) /*!40101 CHARACTER SET ascii COLLATE ascii_general_ci */ NOT NULL,
 \`created\` datetime NOT NULL DEFAULT '1000-01-01 00:00:00',
 \`idx\` int(11) UNSIGNED NOT NULL DEFAULT '0',
 \`uid\` int(11) UNSIGNED NOT NULL DEFAULT '0',
 \`subject\` varchar(255) NOT NULL,
 \`from\` varchar(255) NOT NULL,
 \`to\` varchar(255) NOT NULL,
 \`cc\` varchar(255) NOT NULL,
 \`date\` datetime NOT NULL DEFAULT '1000-01-01 00:00:00',
 \`size\` int(11) UNSIGNED NOT NULL DEFAULT '0',
 \`headers\` text NOT NULL,
 \`structure\` text,
 PRIMARY KEY(\`message_id\`),
 INDEX \`created_index\` (\`created\`),
 INDEX \`index_index\` (\`user_id\`, \`cache_key\`, \`idx\`),
 UNIQUE \`uniqueness\` (\`user_id\`, \`cache_key\`, \`uid\`),
 CONSTRAINT \`user_id_fk_messages\` FOREIGN KEY (\`user_id\`)
   REFERENCES \`users\`(\`user_id\`)
   /*!40008
     ON DELETE CASCADE
     ON UPDATE CASCADE */
) /*!40000 ENGINE=INNODB */ /*!40101 CHARACTER SET utf8 COLLATE utf8_general_ci */;


-- Table structure for table \`cache\`

CREATE TABLE \`cache\` (
 \`cache_id\` int(10) UNSIGNED NOT NULL AUTO_INCREMENT,
 \`cache_key\` varchar(128) /*!40101 CHARACTER SET ascii COLLATE ascii_general_ci */ NOT NULL ,
 \`created\` datetime NOT NULL DEFAULT '1000-01-01 00:00:00',
 \`data\` longtext NOT NULL,
 \`user_id\` int(10) UNSIGNED NOT NULL DEFAULT '0',
 PRIMARY KEY(\`cache_id\`),
 INDEX \`created_index\` (\`created\`),
 INDEX \`user_cache_index\` (\`user_id\`,\`cache_key\`),
 CONSTRAINT \`user_id_fk_cache\` FOREIGN KEY (\`user_id\`)
   REFERENCES \`users\`(\`user_id\`)
   /*!40008
     ON DELETE CASCADE
     ON UPDATE CASCADE */
) /*!40000 ENGINE=INNODB */ /*!40101 CHARACTER SET utf8 COLLATE utf8_general_ci */;


-- Table structure for table \`contacts\`

CREATE TABLE \`contacts\` (
 \`contact_id\` int(10) UNSIGNED NOT NULL AUTO_INCREMENT,
 \`changed\` datetime NOT NULL DEFAULT '1000-01-01 00:00:00',
 \`del\` tinyint(1) NOT NULL DEFAULT '0',
 \`name\` varchar(128) NOT NULL,
 \`email\` varchar(128) NOT NULL,
 \`firstname\` varchar(128) NOT NULL,
 \`surname\` varchar(128) NOT NULL,
 \`vcard\` text NULL,
 \`user_id\` int(10) UNSIGNED NOT NULL DEFAULT '0',
 PRIMARY KEY(\`contact_id\`),
 INDEX \`user_contacts_index\` (\`user_id\`,\`email\`),
 CONSTRAINT \`user_id_fk_contacts\` FOREIGN KEY (\`user_id\`)
   REFERENCES \`users\`(\`user_id\`)
   /*!40008
     ON DELETE CASCADE
     ON UPDATE CASCADE */
) /*!40000 ENGINE=INNODB */ /*!40101 CHARACTER SET utf8 COLLATE utf8_general_ci */;


-- Table structure for table \`identities\`

CREATE TABLE \`identities\` (
 \`identity_id\` int(10) UNSIGNED NOT NULL AUTO_INCREMENT,
 \`del\` tinyint(1) NOT NULL DEFAULT '0',
 \`standard\` tinyint(1) NOT NULL DEFAULT '0',
 \`name\` varchar(128) NOT NULL,
 \`organization\` varchar(128) NOT NULL DEFAULT '',
 \`email\` varchar(128) NOT NULL,
 \`reply-to\` varchar(128) NOT NULL DEFAULT '',
 \`bcc\` varchar(128) NOT NULL DEFAULT '',
 \`signature\` text,
 \`html_signature\` tinyint(1) NOT NULL DEFAULT '0',
 \`user_id\` int(10) UNSIGNED NOT NULL DEFAULT '0',
 PRIMARY KEY(\`identity_id\`),
 CONSTRAINT \`user_id_fk_identities\` FOREIGN KEY (\`user_id\`)
   REFERENCES \`users\`(\`user_id\`)
   /*!40008
     ON DELETE CASCADE
     ON UPDATE CASCADE */
) /*!40000 ENGINE=INNODB */ /*!40101 CHARACTER SET utf8 COLLATE utf8_general_ci */;


/*!40014 SET FOREIGN_KEY_CHECKS=1 */;

"
EOSQLR

	mysql -u$RC_DB_USER -p$RC_DB_PASS $RC_DB_DATABASE <$ROUNDCUBE_MYSQL_INITIAL_TEMP
	rm -fr ROUNDCUBE_MYSQL_INITIAL_TEMP	

	## Configure settings in roundcube
	ROUNDCUBE_DATABASE_CONF=/etc/roundcube/debian-db.php
	ROUNDCUBE_CONF=/etc/roundcube/main.inc.php
	ROUNDCUBE_APACHE_CONF=/etc/apache2/conf.d/roundcube

	## Make backup if this is the first time, do not overwrite in further runs
        if ! [ -f $ROUNDCUBE_DATABASE_CONF.prepostfixadminbackup ]; then
                cp $ROUNDCUBE_DATABASE_CONF $ROUNDCUBE_DATABASE_CONF.prepostfixadminbackup
                echo "Roundcube database configuration backup saved at: $ROUNDCUBE_DATABASE_CONF.prepostfixadminbackup"
        fi

	## Make backup if this is the first time, do not overwrite in further runs
        if ! [ -f $ROUNDCUBE_CONF.prepostfixadminbackup ]; then
                cp $ROUNDCUBE_CONF $ROUNDCUBE_CONF.prepostfixadminbackup
                echo "Roundcube configuration backup saved at: $ROUNDCUBE_CONF.prepostfixadminbackup"
        fi
	
	echo "Warning: Overwrite $ROUNDCUBE_DATABASE_CONF? (Ctrl-c to abort)" && [ $FORCE = "no" ] && read
	echo <<ROUNDCUBEDATABASECONF >$ROUNDCUBE_DATABASE_CONF "
<?php 
\$dbuser='$RC_DB_USER';
\$dbpass='$RC_DB_PASS';
\$basepath='';
\$dbname='$RC_DB_DATABASE';
\$dbserver='localhost';
\$dbport='';
\$dbtype='mysql';
?>
"
ROUNDCUBEDATABASECONF

	sed -i "s/^\$rcmail_config\['htmleditor'\].*/\$rcmail_config['htmleditor'] = TRUE;/g" $ROUNDCUBE_CONF
	sed -i "s/^\$rcmail_config\['create_default_folders'\].*/\$rcmail_config['create_default_folders'] = TRUE;/g" $ROUNDCUBE_CONF

	## IMPROVE:
	#$rcmail_config['plugins'] = array("managesieve", "password")
	#$rcmail_config['default_host'] = "localhost";

	## Configure apache
	grep -q '^ \+[^#]*Alias' $ROUNDCUBE_APACHE_CONF && echo "Warning: Write aliases again to $ROUNDCUBE_APACHE_CONF? (Ctrl-c to abort)" && [ $FORCE = "no" ] && read
	echo <<ROUNDCUBEAPACHECONF >>$ROUNDCUBE_APACHE_CONF "
Alias /roundcube/program/js/tiny_mce/ /usr/share/tinymce/www/
Alias /roundcube /var/lib/roundcube
"
ROUNDCUBEAPACHECONF

	/etc/init.d/apache2 restart

}



set_global_default_env

usage(){
	echo <<USAGE "
Usage: $(basename $0) [OPTION...]

$(basename $0) will attempt to install all configurations for postfixadmin by default,
assumes that the current postfix and dovecot configurations are the base ones in 
Debian Squeeze. It will use default settings for usernames and database names. 
It will generate random passwords and the relevant ones will be informed. 

Options:
 -a <email>	email address to used as admin user in postfixadmin. DEFAULT: $PFA_ADMIN_USER
 -p <password>	password to be setup for the admin user in postixadmin. DEFAULT: RANDOM
 -j <dbuser>	postfixadmin mysql database username to be setup. DEFAULT: $PFA_DB_USER
 -k <dbpass>	postfixadmin mysql password to be assigned to the mysql database user. DEFAULT: RANDOM
 -d <dbname>	postfixadmin mysql database name. DEFAULT: $PFA_DB_DATABASE
 -q <dbuser>	roundcube mysql database username to be setup. DEFAULT: $RC_DB_USER
 -w <dbpass>    roundcube mysql password to be assigned to the mysql database user. DEFAULT: RANDOM
 -e <dbname>	roundcube mysql database name. DEFAULT: $RC_DB_DATABASE
 -v <user>	name of the unix user that will hold the mailboxes. DEFAULT: $VMAIL_USER
 -f		force the install, prompts in error/warnings are disabled. export MYSQL_ROOT_PASS=password 
		can be used with this setting for unattended installs.
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
   configure_spamassassin	configures spamassassin
   configure_postfix		configures postfix
   install_roundcube		installs roundcube
   configure_roundcube		configures roundcube
"
USAGE
}



## Parse args and execute tasks
while getopts 'a:p:j:k:d:q:w:e:v:t:fh' option; do
	case $option in
	a)	PFA_ADMIN_USER=$OPTARG;;
	p)	PFA_ADMIN_PASS=$OPTARG;;
	j)	PFA_DB_USER=$OPTARG;;
	k)	PFA_DB_PASS=$OPTARG;;
	d)	PFA_DB_DATABASE=$OPTARG;;
	q)	RC_DB_USER=$OPTARG;;
	w)	RC_DB_PASS=$OPTARG;;
	e)	RC_DB_DATABASE=$OPTARG;;
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
Debian Squeeze. It will use default settings for usernames and database names. 
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
	[ $? -ne "0" ] && exit 1
	configure_spamassassin
	[ $? -ne "0" ] && exit 1
	configure_postfix
	[ $? -ne "0" ] && exit 1
	install_roundcube
	[ $? -ne "0" ] && exit 1
	configure_roundcube
	
	echo <<EOF "
#################################################################
# 
# Postfixadmin located at: http://your-ip/postfixadmin								
# Assigned Postfixadmin Admin username: $PFA_ADMIN_USER	
# Assigned Postfixadmin Admin password: $PFA_ADMIN_PASS
# Roundcube located at: http://your-ip/roundcube 
#
#################################################################
"	
EOF

else
	## Detect existing vars
	VMAIL_UID=$(getent passwd | grep '^'$VMAIL_USER':' | awk -F':' '{print $3}')
	VMAIL_GID=$(getent passwd | grep '^'$VMAIL_USER':' | awk -F':' '{print $4}')
	VMAIL_HOME=$(getent passwd | grep '^'$VMAIL_USER':' | awk -F':' '{print $6}')

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
# Roundcube Mysql username: $RC_DB_USER
# Roundcube Mysql password: $RC_DB_PASS
# Roundcube Mysql database: $RC_DB_DATABASE
#################################################################
"
EOF
	for t in $( echo $TASKS | tr ',' ' '); do
		$t
	done
fi

exit 0

