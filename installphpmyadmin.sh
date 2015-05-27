#!/bin/bash

#
# $Id: installphpmyadmin.sh 312 2013-04-16 03:24:19Z john $
#
# Install phpmyadmin
# Rimuhosting.com
# Script provided with absolutely no warranty
#
# TODO: configure basic http auth in front of phpmyadmin
#

DISTRO=
RELEASE=
ERRORMSG=
NEEDMYSQL=
SUPPORT_EMAIL="support@rimuhosting.com"

# used for detection of caller (ie in login shell or called from another script)
CALLER=$(ps ax | grep "^ *$PPID" | awk '{print $NF}')

APTMOD="-y "
if [ -e /etc/debian_version ]; then
  APTMOD="-y -qq"
fi
WGET_OPTS="--tries=2 --timeout=10 --quiet"
export DEBIAN_FRONTEND="noninteractive"

##
# debug option so we can make the script less noisy, but still see
# what happened if needed
export DEBUG=y
export DEBUG_LOG_FILE="/dev/null"
if [[ ! -z "$DEBUG" ]]; then
  export DEBUG_LOG_FILE="/root/debug-$(basename $0).log"
  echo > "$DEBUG_LOG_FILE"
fi
function echolog {
  echo "$*" | tee -a "$DEBUG_LOG_FILE"
}

###
# Tell us what version the script is... duh :) but only if we are in an
# login shell session.
function version {
  [[ "$CALLER" == "-bash" ]] || return 0
  echolog "
 $Id: installphpmyadmin.sh 312 2013-04-16 03:24:19Z john $null
 Copyright Rimuhosting.com
"
  [ ! -z "$DEBUG" ] && echo -e "! Debugging mode active, logging extra output to $DEBUG_LOG_FILE\n"
}

###
# Handy function to tell users whats what
function usage {
  echolog " Usage: $(basename $0) <--help> | <--installmysql>
  Tries to install default phpmyadmin verison for distro. If you need a manual
  install from non-distro sources (ie from the upstream community release)
  please contact our support team at $SUPPORT_EMAIL

  Options         Description
  --help          prints out this helpful message
  --need-mysql    install and configure mysql in a secure way first
"
}

###
# Take parameters as given on command line and set those up so we can do
# cooler stuff, or complain that nothing will work. Set some reasonable
# defaults so we dont have to type so much.
function parsecommandline {
  while [ -n "$1" ]; do
    case "$1" in
    -h|help|-help|--help|?|-?|--? )
      ERRORMSG="just run the command with no paramters"
      return 1;
      ;;
    --need-mysql )
      NEEDMYSQL=y
      ;;
    * )
      ERRORMSG="'$(basename $0)' given with unsupported paremter '$1'"
      return 1
      ;;
    esac
    shift
  done

  if [ $(id -u) -ne 0 ] ; then
    ERRORMSG="you need to be logged in as the 'root' user to run this (e.g. sudo $0 $* )"
    return 1
  fi

  # detect distro and release
  if [ -e /etc/redhat-release ]; then
      DISTRO=( `grep release /etc/redhat-release | awk '{print $1}'` )
      RELEASE=( `grep release /etc/redhat-release | awk '{print $3}' | cut -d. -f1` )
  elif [ -e /etc/debian_version ]; then
      if ( ! which lsb_release >/dev/null ); then
          echolog "  ...installing 'lsb_release' command"
          apt-get $APTMOD install lsb-release  >> "$DEBUG_LOG_FILE" 2>&1
          if [[ $? -ne 0 ]]; then ERRORMSG="Error: installing lsb_release package failed"; return 1; fi
      fi
      DISTRO=$( lsb_release -is )
      RELEASE=$( lsb_release -cs )
  else
      echolog "! Warning: Running on unknown distro, some features may not work as expected"
  fi
  [[ -z "$DISTRO" ]] && echolog "! Warning: Was not able to identify distribution"
  [[ -z "$RELEASE" ]] && echolog "! Warning: Was not able to identify release"

  ARCH="$(uname -m)"
  if [[ "$ARCH" != "x86_64" ]]; then
    # rhel6 supports i386 no more
    [[ "$RELEASE" == "6" ]] && ARCH="i686" || ARCH="i386"
  fi

  return 0
}

function setup_epel() {
 echo '  ...Setting up epel repo'
if [[ "$RELEASE" == "6" ]]; then
echo "     EPEL el6 rpm key"
      if ! rpm -qa | grep -q gpg-pubkey-0608b895-4bd22942; then
      wget --quiet http://downloads.rimuhosting.com/RPM-GPG-KEY-EPEL-6
      rpm --import RPM-GPG-KEY-EPEL-6
      mv RPM-GPG-KEY-EPEL-6 /etc/pki/rpm-gpg/
      wget --quiet http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
      rpm -Uh epel-release-6-8.noarch.rpm
      else 
      echo " Looks like epel might be setup already"
      fi
else 
echo "     EPEL el5 rpm key"
      if ! rpm -qa | grep -q gpg-pubkey-217521f6-45e8a532; then
      wget --quiet http://downloads.rimuhosting.com/RPM-GPG-KEY-EPEL
      rpm --import RPM-GPG-KEY-EPEL
      mv RPM-GPG-KEY-EPEL /etc/pki/rpm-gpg/
      http://download.fedoraproject.org/pub/epel/5/x86_64/epel-release-5-4.noarch.rpm
      wget --quiet http://download.fedoraproject.org/pub/epel/6/x86_64/epel-release-5-4.noarch.rpm
      rpm -Uh epel-release-5-4.noarch.rpm
      else
      echo " Looks like epel might be setup already"
      fi
fi
}

###
# install phpmyadmin and requirements
function installphpmyadmin {
  echolog "  ...verifying mysql server status"
  if [ ! -z "$NEEDMYSQL" ]; then

# Generate random pass, setting one manually w/ installmysql script seems to cause a loop 
MYSQLPASS=$(cat /dev/urandom | tr -dc "a-zA-Z0-9@#*=" | fold -w 8 | head -1)

    wget ${WGET_OPTS} http://proj.ri.mu/installmysql.sh -O /root/installmysql.sh 
    bash /root/installmysql.sh --adminpass $MYSQLPASS
    if [ $? -ne 0 ]; then
      ERRORMSG="failed installing/configuring mysql"
      return 1
    fi
  fi
  if [ $(ps auxf | grep -v grep | grep -c mysql) -eq 0 ]; then
    ERRORMSG="It looks like mysql is not running. Consider calling this script
with the --need-mysql option.
"
    return 1
  else 
    echolog "     mysql is running"
  fi
  if [ $(mysql -e "use mysql;" 2>&1 | grep -c "Access Denied") -ne 0 ]; then
    ERRORMSG="It looks like there is no root user password set on
mysql. Consider calling this script with the --need-mysql option.
"
    return 1
  else 
    echolog "     mysql root account seems secured"
  fi

if [ -e /etc/debian_version ]; then
  echolog "  ...installing debian package"
  apt-get ${APTMOD} update >> "$DEBUG_LOG_FILE" 2>&1
  apt-get ${APTMOD} install phpMyAdmin >> "$DEBUG_LOG_FILE" 2>&1
  if [ $? -ne 0 ]; then
    ERRORMSG="error installing main package, unable to proceed"
    return 1
  fi
else
  echolog "  ...installing RPM package from EPEL"
  yum -y install phpmyadmin
fi


  echolog "  ...finalising application configuration for $DISTRO"
  if [[ "$DISTRO" == "CentOS" ]]; then
    # overwrite installed copy with our own modified version
    configfile="/usr/share/phpmyadmin/config.inc.php"
    random_chars=$(echo $(date) $(hostname) $(whoami) $(uname -a) | md5sum | cut -c1-10)
    cat << EOF > "$configfile"
 <?php
\$cfg['blowfish_secret'] = '$random_chars';

/* Servers configuration */
\$i = 0;

/* Server localhost (cookie) [1] */
\$i++;
\$cfg['Servers'][\$i]['host'] = 'localhost';
\$cfg['Servers'][\$i]['extension'] = 'mysql';
\$cfg['Servers'][\$i]['connect_type'] = 'tcp';
\$cfg['Servers'][\$i]['compress'] = false;
\$cfg['Servers'][\$i]['auth_type'] = 'cookie';

/* End of servers configuration         */
?>
EOF
fi

  echolog "  ...finalising apache configuration for $DISTRO"
  if [[ "$DISTRO" == "CentOS" ]]; then
# use Centos 6 config:
   if [ -f /etc/httpd/conf.d/phpMyAdmin.conf ]; then
echo "* Looks like a Centos 6 config, let's use that." 
	sed -i '/Deny from All/s/^/# /' /etc/httpd/conf.d/phpMyAdmin.conf
	sed -i 's|Alias /phpmyadmin|Alias /pma|' phpMyAdmin.conf
	sed -i 's|Alias /phpMyAdmin|Alias /pma|' phpMyAdmin.conf
  else 
# overwrite installed copy with our own modified version (centos 5)
    cat << EOF > "/etc/httpd/conf.d/phpmyadmin.conf"
<Directory "/usr/share/phpmyadmin">
  Order Deny,Allow
  Allow from all
</Directory>
Alias /pma /usr/share/phpmyadmin
EOF
 fi
fi

  service="apache2"
  [ -e /etc/redhat-release ] && service="httpd"
  if [ $(netstat -plant | grep ":80 " | grep -c $service) -ne 0 ]; then
    echolog "  ...restarting apache web server"
    /etc/init.d/$service restart >> "$DEBUG_LOG_FILE" 2>&1
  else
    echolog "! Warning: apache web service doesnt seem active, start that manually?"
  fi

  if [[ "$NEEDMYSQL" == "y" ]]; then
    echolog "* MySQL root password set to: $MYSQLPASS"
  fi

  ipaddr="$(ifconfig eth0 | grep "inet addr:" | awk '{print $2}' | cut -d: -f2)"

  if [[ -e /etc/redhat-release ]]; then
    echolog "* phpMyAdmin is now installed and will be visible on http://$ipaddr/pma"
  else
    # probably debian based, manual fixups required
    echolog "  This version requires a couple of post install tasks to be completed 
  manually. Please consider running the below snippet...

    sed -i 's|Alias /phpmyadmin|Alias /pma|' /etc/phpmyadmin/apache.conf
    dpkg-reconfigure -plow phpmyadmin
  
  Consider reviewing http://www.hardened-php.net/hphp/troubleshooting.html
  After that phpMyAdmin is now installed and will be visible on http://$ipaddr/pmaa

  Also consider using a ssh tunnel to connect to phpMyAdmin on localhost. 
  A guide here: http://arstechnica.com/civis/viewtopic.php?f=16&t=1081078"
  fi
  echolog "  Full documentation for phpmyadmin is available on the developer home page
  at http://www.phpmyadmin.net/home_page/docs.php"

  return 0
}


#######################
# run the stuff
#######################

version
echolog "* Installing phpMyAdmin install from default distro release"
parsecommandline $*
if [[ $? -ne 0 ]]; then
  echo
  usage
  echolog "! Error from command: $ERRORMSG"
  exit 1
fi
if [ -e /etc/redhat-release ]; then
setup_epel
fi
installphpmyadmin
if [[ $? -ne 0 ]]; then
  echo
  echolog "! Error from install: $ERRORMSG"
  echo
  exit 1
fi
exit 0

# OBSOLETE CODE BELOW 
# below functions kept as a reference since they are still good for a 'source'
# install which we may restore at some point

###
# get the lastest stable (release) version from upstream
# deprecated since we try to do a distro install now
function __whatisstable {
  LATESTSTABLE=`wget -q 0 http://www.phpmyadmin.net/home_page/downloads.php | grep "<h2>phpMyAdmin $MAJORVERSION" downloads.php | sed -e :a -e 's/<[^>]*>//g;/</N;//ba' | sed 's/^[ \t]*//;s/[ \t]*$//' | awk '{ print $2 }'`
  if [ $? -ne 0 ]; then
    echo "error getting phpmyadmin version, using default"
  fi
  echo "* Latest stable version appears to be: $LATESTSTABLE but don't take my word for it"
  VERSION="phpMyAdmin-$LATESTSTABLE-all-languages"
}
function __downloadtar {
  mkdir -p /var/www/html
  cd /var/www/html/
  echo -n now in `pwd`
  echo "==========="
  echo "Installing $VERSION on https://$ip/phpMyAdmin at /var/www/html/phpMyAdmin from http://transact.dl.sourceforge.net/sourceforge/phpmyadmin/$VERSION.tar.gz..."
  echo "==========="
  wget -O - "http://transact.dl.sourceforge.net/sourceforge/phpmyadmin/$VERSION.tar.gz" | tar xz
  if [ $? -ne 0 ]; then
    echo "Failed getting http://transact.dl.sourceforge.net/sourceforge/phpmyadmin/$VERSION.tar.gz, check the version" >&2
    return 1
  fi
}
function __installphpmyadmin {
ip=$(ifconfig | grep --after-context=1 "eth0 " | grep inet | cut -d: -f2 | cut -f1 -d' ')
  if [ -e /var/www/html/phpMyAdmin ]; then
    mv /var/www/html/phpMyAdmin /var/www/html/phpMyAdmin.old
  fi
  mv /var/www/html/$VERSION /var/www/html/phpMyAdmin
  cd /var/www/html/phpMyAdmin
  # use a cookie login
  random_chars=$(echo $(date) $(hostname) $(whoami) $(uname -a) | md5sum | cut -c1-10)

  cat << EOF > config.inc.php
<?php
\$cfg['blowfish_secret'] = '$random_chars';

/* Servers configuration */
\$i = 0;

/* Server localhost (cookie) [1] */
\$i++;
\$cfg['Servers'][\$i]['host'] = 'localhost';
\$cfg['Servers'][\$i]['extension'] = 'mysql';
\$cfg['Servers'][\$i]['connect_type'] = 'tcp';
\$cfg['Servers'][\$i]['compress'] = false;
\$cfg['Servers'][\$i]['auth_type'] = 'cookie';

/* End of servers configuration         */
?>
EOF

  # to avoid the following error: The $cfg[PmaAbsoluteUri] directive MUST be set in your configuration file
  if [ -e /etc/redhat-release ]; then
    apt-get update; apt-get  -y install php-mbstring php-mcrypt
  fi

echo " * MySQL Information"
echo $NEEDMYSQL
echo $MYSQLPASS
if [[ "$NEEDMYSQL" == "y" ]]; then
  echo "MySQL root password set to: $MYSQLPASS"
fi  
  # this command will output the URL on which phpMyAdmin is running:
  echo You probably want to add in an Alias into your apache similar to the following
  echo Alias /phpMyAdmin/ /var/www/html/
  echo This will allow you too use it on any domain on the server.
  echo Log in at the following URL with your MySQL UserName and password:
  echo https://$ip/phpMyAdmin/ # e.g. https://123.456.789.12/phpMyAdmin
}

#  if [[ "$DISTRO" == "CentOS" ]]; then
#    echolog "  ...verify $ARCH $DISTRO $RELEASE rpmforge repository for backported packages"
#    RPMFORGE="http://packages.sw.be/rpmforge-release"
#    PACKAGE="rpmforge-release-0.5.2-2.el${RELEASE}.rf.${ARCH}.rpm"
    # only install if the same package is not already installed
#    if [[ "$(rpm -qa rpmforge-release).${ARCH}.rpm" != "$PACKAGE" ]]; then
#      echolog "     configured missing or updatable rpmforge repository"
#      rpm --import http://apt.sw.be/RPM-GPG-KEY.dag.txt >> "$DEBUG_LOG_FILE" 2>&1
#      wget ${WGET_OPTS} ${RPMFORGE}/${PACKAGE}
#      if [ $? -ne 0 ]; then
#        ERRORMSG="failed downloading $DISTRO repository information"
#        return 1
#      fi
#      rpm -K ${PACKAGE} >> "$DEBUG_LOG_FILE" 2>&1
#      if [ $? -ne 0 ]; then
#        ERRORMSG="failed verifying repository information, check/configure manually?"
#        return 1
#      fi
#      rpm -Uvh ${PACKAGE} >> "$DEBUG_LOG_FILE" 2>&1
#      if [ $? -ne 0 ]; then
#        ERRORMSG="error installing repository update, investigate manually"
#        return 1
#      fi
#      rm -f ${PACKAGE}*

      # rpmforge is large, apt needs tweaking to cope
#      [[ -f /etc/apt/apt.conf && $(grep -c "Cache-Limit" /etc/apt/apt.conf) -eq 0 ]] && echo "APT::Cache-Limit "167772160";" >> /etc/apt/apt.conf
#    fi
#  fi

