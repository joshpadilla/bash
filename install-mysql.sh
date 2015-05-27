#!/bin/bash

#
# Automated Mysql installer/configurator, tested to work on CentOS5+,
# Ubuntu LTS, and Debian5+ dervived systems. objective is to install and safely
# secure mysql with an admin user password to /root/.mysqlp and verify mysql
# is running sanely
# Created 2011-Jan-20th by Glenn Enright
#

# support defaults
export DEBIAN_FRONTEND="noninteractive"
CALLER=$(ps ax | grep "^ *$PPID" | awk '{print $NF}')

# operating defaults
ERRORMSG=
NOPROMPT=
NOPERL=
NOPHP=
NOAPACHE=
NOSECURE=

# login defaults
DEFAULTADMINUSER="root"
ADMINUSER=
ADMINPASS=

# Add some debug in the future
DEBUG_LOG_FILE=/dev/null

function version {
 echo "
 $0 ($Id: installmysql.sh 310 2013-04-16 02:39:25Z john $)
 Installs and secures the mysql packages provided by your system
"
}

###
# Function: usage
# Handy function to tell users how to...
#
function usage {
  echo " Usage: $0 [--noprompt] [--adminuser <username>] [--adminpass <password>]
      [--minimal] [--noperl] [--nophp] [--noapache]

  Option:         Description:
  --noprompt      run script without user interaction
  --adminuser     mysql admin user with full access to server
  --adminpass     password for the admin user
  --minimal       implies all the no* options below
  --noperl        dont install additional libraries for perl support
  --noapache      dont install additional libraries for Apache support
  --nophp         dont install additional libraries for PHP support
  --nosecure      skipp all the security steps
"
}

###
# Function: parsecommandline
# Take parameters as given on command line and set those up so we can do
# cooler stuff, or complain that nothing will work. Set some reasonable
# defaults so we dont have to type so much.
#
function parsecommandline {
  while [ -n "$1" ]; do
    PARAM=$1
    case "$1" in
    --adminuser)
      shift
      if [[ -z "$1" ]]; then
        ERRORMSG="$PARAM given without value"
        return 1
      fi
      ADMINUSER=$1
      ;;
    --adminpass)
      shift
      if [[ -z "$1" ]]; then
        ERRORMSG="$PARAM given without value"
        return 1
      fi
      ADMINPASS=$1
      ;;
    h|-h|--help|?|-?)
      version
      usage
      exit 0
      ;;
    --minimal)
      NOPERL=n
      NOPHP=n
      NOAPACHE=n
      NOSECURE=n
      ;;
    --noperl)
      NOPERL=n
      ;;
    --nophp)
      NOPHP=n
      ;;
    --noapache)
      NOAPACHE=n
      ;;
    --nosecure)
      NOSECURE=n
      ;;
    --noprompt)
      NOPROMPT=n
      ;;
    *)
      ERRORMSG="unrecognised paramter '$PARAM'"
      return 1
      ;;
    esac
    shift
  done

  ADMINUSER=${ADMINUSER:-$DEFAULTADMINUSER}

  if [[ $(id -u) != "0" ]] ; then
    ERRORMSG="you need to be logged in as the 'root' user to run this (e.g. sudo $0 $* )"
    return 1
  fi
  if [ -e "/etc/psa/.psa.shadow" ]; then
    ERRORMSG="this seems to be a plesk server, if MySQL is not already installed do that through the Plesk CP."
    return 1
  fi
}


##
# Function: installmysql
# actually install mysql if needed. typically this should already be in place,
# but make sure anyhow, and start the service
#
function installmysql {
  echo "* Installing for mysql server"
  if [[ ! $(which mysqld_safe 2>/dev/null) ]]; then
    echo -n "  ...attempting to install database core:"
    if [[ -e /etc/redhat-release ]]; then
      packlist="mysql mysql-server mysql-connector-odbc"
    else
      packlist="mysql-common mysql-client mysql-server libmyodbc"
    fi
    for i in $packlist; do
      echo -n " $i"
      #if [[ -e /etc/redhat-release ]]; then
	#yum --quiet install $i  >> "$DEBUG_LOG_FILE" 2>&1
	# else
        apt-get -y -qq install $i  >> "$DEBUG_LOG_FILE" 2>&1
       # fi
      if [[ $? -ne 0 ]]; then
        echo
        ERRORMSG="package $i install failed"
        return 1
      fi
    done
    echo
  fi

  if [[ -z $NOPERL ]]; then
    echo -n "  ...installing perl libraries:"
    for i in libdbd-mysql-perl libdbi-perl; do
      apt-get -y -qq install $i  >> /dev/null 2>&1
      if [[ $? -eq 0 ]]; then
        echo -n " $i"
      fi
    done
    echo
  fi
  if [[ -z $NOPHP ]]; then
    echo -n "  ...installing php libraries:"
    for i in php-mysql php-pdo php5-mysql php5-odbc; do
      apt-get -y -qq install $i  >> /dev/null 2>&1
      if [[ $? -eq 0 ]]; then
        echo -n " $i"
      fi
    done
    echo
  fi
  if [[ -z $NOAPACHE ]]; then
    echo -n "  ...installing apache libraries:"
    for i in apr-util-mysql libaprutil1-dbd-mysql; do
      apt-get -y -qq install $i  >> /dev/null 2>&1
      if [[ $? -eq 0 ]]; then
        echo -n " $i"
      fi
    done
    echo
  fi

  echo "  ...detecting startup script"
  [[ -e /etc/init.d/mysqld ]] && INITSCRIPT="/etc/init.d/mysqld"
  [[ -e /etc/init.d/mysql ]] && INITSCRIPT="/etc/init.d/mysql"
  # fix for rimuhosting.com disabled mysql server script in ubuntu lucid
  [[ -e /etc/init/mysql.conf.disabled ]] && mv /etc/init/mysql.conf{.disabled,}
  [[ -e /etc/init/mysql ]] && INITSCRIPT="service mysql"
  if [[ -z $INITSCRIPT ]]; then
    ERRORMSG="unable to determine MySQL startup script, this should not happen (BUG)"
    return 1
  fi
  echo "  ...running MySQL startup script"
  $INITSCRIPT restart >> /dev/null 2>&1

  echo "  ...setting mysql to start on boot"
  if [[ -e /etc/redhat-release ]]; then
    chkconfig --add mysqld
    chkconfig mysqld on
  else
    update-rc.d mysql defaults
  fi

  echo -n "  ...waiting for service to settle"
  for i in $(seq 5 -1 1); do sleep 1; echo -n " $i"; done;
  echo

  if [[ $($INITSCRIPT status | grep -c stop) > 0 ]]; then
    ERRORMSG="mysql not started cleanly, this should not happen (BUG)"
    return 1
  fi

  if [[ ! -z "$NOSECURE" ]]; then
    echo "  ...skipping all security questions by request"
    return
  fi
  mysql -u"$ADMINUSER" -e "use mysql;"  >> /dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo "  ...no superuser password set"
    NOSUPER='y'
  elif [ -e /root/.mysqlp ]; then # existing password secret
    echo -n "  ...found password secret, "
    mysql -u"$ADMINUSER" -p"$(cat /root/.mysqlp)" -e "use mysql;"  >> /dev/null 2>&1
    if [ $? -ne 0 ]; then
      echo "but it doesnt work, ignoring."
    else
      [[ ! -z "$ADMINPASS" ]] && echo "updating it" || echo "keeping it."
      OLDPASS="$(cat /root/.mysqlp)"
    fi
  elif [[ ! -z "$ADMINPASS" ]]; then
    echo -n "  ...using provided password"
    if [[ ! -z "$NOSUPER" ]]; then
      mysql -u"$ADMINUSER" -p"$ADMINPASS" -e "use mysql;"  >> /dev/null 2>&1
      if [ $? -ne 0 ]; then
        echo ", but testing that doesnt work"
        ERRORMSG="can not connect with the provided credentials, bailing"
        return 1
      fi
    fi
    echo
  fi
  if [[ -z "$ADMINPASS" && -z "$OLDPASS" ]]; then
    if [[ -z "$NOPROMPT" ]]; then
      echo "  ...no password secret found or given."
      yn=
      while [[ "$yn" != 'y' && "$yn" != 'n' ]]; do
        echo -n "  Do you want to enter a new '$ADMINUSER' user password (Y/n)? "
        read yn
        [[ "$yn" == "" ]] && yn='y' # accept default value
        yn=$(echo $yn | tr [:upper:] [:lower:])
      done
      while [[ "$yn" == 'y' ]]; do
        echo -n "    Enter new password: "
        read -s ADMINPASS
        echo
        if [[ "$ADMINPASS" == "" ]]; then
          echo -n "    Sorry, you can't use an empty password here, retry (Y/n)? "
          read yn
          yn=$(echo $yn | tr [:upper:] [:lower:])
          [[ "$yn" != 'n' ]] && yn='y'
          continue
        fi
        echo -n "    Re-enter new password: "
        read -s CHECKPASS
        echo
        if [ "$ADMINPASS" != "$CHECKPASS" ]; then
          echo -n "    Sorry, passwords do not match, retry (Y/n)? "
          read yn
          yn=$(echo "$yn" | tr [:upper:] [:lower:])
          [[ "$yn" != 'n' ]] && yn='y'
          continue
        fi
        break
      done
    else
      ERRORMSG="no password secret found or given and running in --noprompt mode, secure Mysql manually"
      return 1
    fi
  fi

  if [[ ! -z "$NOSUPER" && ! -z "$ADMINPASS" ]]; then
    echo "  ...setting password"
    mysql -u"$ADMINUSER" -e "UPDATE mysql.user SET Password=PASSWORD('$ADMINPASS') WHERE User='root'; FLUSH PRIVILEGES;"  >> /dev/null 2>&1
    if [[ $? -ne 0 ]]; then
      ERRORMSG="unable to set $ADMINUSER password, set manually"
      return 1
    fi
  elif [[ ! -z "$OLDPASS" && ! -z "$ADMINPASS" ]]; then
    echo "  ...updating password"
    mysql -u"$ADMINUSER" -p"$OLDPASS" -e "UPDATE mysql.user SET Password=PASSWORD('$ADMINPASS') WHERE User='root'; FLUSH PRIVILEGES;"  >> /dev/null 2>&1
    if [[ $? -ne 0 ]]; then
      ERRORMSG="unable to set $ADMINUSER password, set manually"
      return 1
    fi
  else
    ADMINPASS="$OLDPASS"
  fi

  if [[ -z "$ADMINPASS" ]]; then
    echo "  ...skipping further tasks since no superuser password set (unsafe, consider running mysql_secure_installation)"
    return
  else # final test to make sure the pass works
    mysql -u"$ADMINUSER" -p"$ADMINPASS" -e "use mysql;"  >> /dev/null 2>&1
    if [ $? -ne 0 ]; then
      ERRORMSG="can not connect with the configured credentials, bailing (BUG)"
      return 1
    fi
    echo "$ADMINPASS" > /root/.mysqlp
  fi

  echo -n "  ...remove remote root access, "
  mysql -u$ADMINUSER -p$ADMINPASS -e "DELETE FROM mysql.user WHERE User='root' AND Host!='localhost';" >> /dev/null 2>&1
  [[ $? -ne 0 ]] && echo "failed but not critical, keep moving..." || echo ok

  echo -n "  ...remove anononymous users, "
  mysql -u$ADMINUSER -p$ADMINPASS -e "DELETE FROM mysql.user WHERE User=''" >> /dev/null 2>&1
  [[ $? -ne 0 ]] && echo "failed but not critical, keep moving..." || echo ok

  echo -n "  ...remove test database, "
  mysql -u$ADMINUSER -p$ADMINPASS -e "DROP DATABASE test;" >> /dev/null 2>&1
  [[ $? -ne 0 ]] && echo "failed but not critical, keep moving..." || echo ok

  echo -n "  ...remove test database privileges, "
  mysql -u$ADMINUSER -p$ADMINPASS -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%'" >> /dev/null 2>&1
  [[ $? -ne 0 ]] && echo "failed but not critical, keep moving..." || echo ok

  echo -n "  ...reloading privilege tables, "
  mysql -u$ADMINUSER -p$ADMINPASS -e "FLUSH PRIVILEGES" >> /dev/null 2>&1
  [[ $? -ne 0 ]] && echo "failed but not critical, keep moving..." || echo ok

  if [ -e /etc/mysql/conf.d/ ]; then
    echo "  ...forcing utf8 connections and codepage support"
    echo "[mysqld]
init_connect='SET collation_connection = utf8_general_ci; SET NAMES utf8;'
# no longer a valid variable name/deprecated
#default-character-set=utf8
character-set-server=utf8
collation-server=utf8_general_ci
" > /etc/mysql/conf.d/forceutf8.cnf
    $INITSCRIPT restart >> /dev/null 2>&1
  fi
  return 0
}


parsecommandline $*
if [[ $? -ne 0 ]]; then
  echo
  version
  usage
  echo "! Error from command: $ERRORMSG"
  echo
  exit 1
fi
[[ -z $NOPROMPT && "$CALLER" == "-bash" ]] && version

installmysql
if [[ $? -ne 0 ]]; then
  echo
  echo "! Error from installer: $ERRORMSG"
  echo
  exit 1
fi
