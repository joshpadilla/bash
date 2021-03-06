#!/bin/bash

#
# ($Id: installconfluence.sh 234 2012-07-28 04:28:59Z glenn $)
#
# Automated confluence installer/configurator, tested to work on CentOS5+,
# Ubuntu LTS, and Debian5+ dervived systems. objective is to install and safely
# secure confluence
# Created 2011-Mar-30th by Glenn Enright
#

# defaults (tweakable :-) )
MEMORYREQUIRED="1024" # min in MB, 512MB per requirements listed in docs is too small w/mysql
APPVERSION="4.2.2"
FILE_SOURCE="http://www.atlassian.com/software/confluence/downloads/binary/atlassian-confluence-${APPVERSION}.tar.gz"
WGET_OPTS="--tries=2 --timeout=10 --quiet"
SUPPORT_EMAIL="support@rimuhosting.com"

# hard setup defaults, shouldnt need changing maunally
DEFAULT_APPNAME="confluence"
DEFAULT_APPUSER="confluence"
DEFAULT_INSTALL_LOC="/usr/local/$DEFAULT_APPNAME"
DEFAULT_DATADIR="$DEFAULT_INSTALL_LOC-data"
DEFAULT_PORT_PREFIX="99"
DEFAULT_DBNAME="confdb"
DEFAULT_DBUSER="confadmin"
DEFAULT_DBPASS="$(cat /dev/urandom | tr -cd "[:alnum:]" | head -c 8)"
INITSCRIPT=

# install values, managed via command line options
APPNAME=
APPUSER=
INSTALL_LOC=
DATADIR=
PORT_PREFIX=
NOPROMPT=
NOJAVA=
NOMYSQL=
RUNONSTARTUP=
DBNAME=
DBUSER=
DBPASS=

# support + debugging defaults, managed via command line options
ERRORMSG=
export DEBIAN_FRONTEND="noninteractive"
CALLER=$(ps ax | grep "^ *$PPID" | awk '{print $NF}')
DEBUG=
DEBUG_LOG="/root/cms_install.log"

###
# Function: echolog
# view std out and append to log
#
function echolog() {
  echo $* | tee -a $DEBUG_LOG
}


###
# Function: version
# tell us about this script
#
function version {
  echo "
 $0
 Copyright RimuHosting.com
 Pre-installs and secures the confluence wiki packages provided by Atlasian
"
#  echo " ** This script is still under development, use at your own risk **
#"
}


###
# Function: usage
# Handy function to tell users how to...
#
function usage {
  echo " Usage: $0 [--help] | [--user <username>] [--appname <name>]
    [--installtarget <dir>] [--datadir <dir>] [--portprefix <prefix>] [--runonstartup]
    [--nojava] [--nomysql|[--dbname <database name>] [--dbuser <username>] ] 
    [--noprompt] [--debug] 

  Option:         Description:
  --dbname        optional name of confluence mysql database (default is $DBNAME)
  --dbuser        optional name of confluence mysql user (default is $DBUSER)
  --dbpass        optional password for confluence database (default is randomised)
  --datadir       absolute folder location for data files (default is $DEFAULT_DATADIR)
  --debug         enables debugging output to $DEBUG_LOG
  --installtarget top level location to install files (default is $DEFAULT_INSTALL_LOC)
  --noprompt      run script without user interaction (not yet implemented)
  --nojava        dont install java
  --nomysql       dont install/setup mysql
  --portprefix    initial three digit network port (default is ${DEFAULT_PORT_PREFIX} eg for http on ${DEFAULT_PORT_PREFIX}90)
  --runonstartup  set confluence to run on server boot (not enabled by default)
  --user          user (and group) service will run as (default is $DEFAULT_APPUSER)
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
    --user)
      shift
      if [[ -z "$1" ]]; then
        ERRORMSG="$PARAM given without value"
        return 1
      fi
      APPUSER="$1"
      ;;
    --appname)
      shift
      if [[ -z "$1" ]]; then
        ERRORMSG="$PARAM given without value"
        return 1
      fi
      APPNAME="$1"
      ;;
    --dbuser)
      shift
      if [[ -z "$1" ]]; then
        ERRORMSG="$PARAM given without value"
        return 1
      fi
      DBUSER="$1"
      ;;
    --dbname)
      shift
      if [[ -z "$1" ]]; then
        ERRORMSG="$PARAM given without value"
        return 1
      fi
      DBNAME="$1"
      ;;
    --dbpass)
      shift
      if [[ -z "$1" ]]; then
        ERRORMSG="$PARAM given without value"
        return 1
      fi
      DBPASS="$1"
      ;;
    --installtarget)
      shift
      if [[ -z "$1" ]]; then
        ERRORMSG="$PARAM given without value"
        return 1
      fi
      INSTALL_LOC="$1"
      ;;
    --datadir)
      shift
      if [[ -z "$1" ]]; then
        ERRORMSG="$PARAM given without value"
        return 1
      fi
      DATADIR="$1"
      ;;
    --portprefix)
      shift
      if [[ -z "$1" ]]; then
        ERRORMSG="$PARAM given without value"
        return 1
      fi
      PORT_PREFIX="$1"
      ;;

    h|-h|--help|?|-?)
      version
      usage
      exit 0
      ;;
    --runonstartup)
      RUNONSTARTUP=y
      ;;
    --debug)
      DEBUG=y
      ;;
    --noprompt)
      NOPROMPT=y
      ;;
    --nojava)
      NOJAVA=y
      ;;
    --nomysql)
      NOMYSQL=y
      ;;
    *)
      ERRORMSG="unrecognised paramter '$PARAM'"
      return 1
      ;;
    esac
    shift
  done

  APPNAME="${APPNAME:-$DEFAULT_APPNAME}"
  APPUSER="${APPUSER:-$DEFAULT_APPUSER}"

  DBUSER="${DBUSER:-$DEFAULT_DBUSER}"
  DBNAME="${DBNAME:-$DEFAULT_DBNAME}"
  DBPASS="${DBPASS:-$DEFAULT_DBPASS}"

  INSTALL_LOC="${INSTALL_LOC:-$DEFAULT_INSTALL_LOC}"
  if [[ -e "${INSTALL_LOC}" ]]; then
    ERRORMSG="install location ${INSTALL_LOC} already exists, aborting install"
    return 1
  fi

  DATADIR=${DATADIR:-"${INSTALL_LOC}-data"}
  if [[ -e "${DATADIR}" ]]; then
    ERRORMSG="data directory ${DATADIR} already exists, aborting install"
    return 1
  fi

  PORT_PREFIX="${PORT_PREFIX:-$DEFAULT_PORT_PREFIX}"
  if [[ $(netstat -plnt | grep -c ":${PORT_PREFIX}90") -gt 0 ]]; then
    ERRORMSG="port prefix seems to be in use already, please check manually"
    return 1
  fi

  INITSCRIPT="/etc/init.d/${APPNAME}"

  [[ -z "${DEBUG}" ]] && DEBUG_LOG="/dev/null"
  echo > "${DEBUG_LOG}"
}


##
# Function: installconfluence
# actually install mysql if needed. typically this should already be in place,
# but make sure anyhow, and start the service
#
function installconfluence {
  echo "  Going to install as ${APPNAME} to ${INSTALL_LOC} with files in ${DATADIR} and running under user ${APPUSER}."
  read -s -p "     Press Ctl-C to quit or any other key to continue
"
  if [[ $(id -u) != "0" ]] ; then
    ERRORMSG="you need to be logged in as the 'root' user to run this (e.g. sudo $0 $* )"
    return 1
  fi

  MEMFOUND=$(free -m | grep 'buffers/cache' | awk '{print $4}')
  if [ "${MEMFOUND}" -lt "${MEMORYREQUIRED}" ]; then
    echo "! Error: not enough available memory found for this install. Only ${MEMFOUND}MB free."
    echo "
  At least ${MEMORYREQUIRED}MB recomended for safe/sane operation. Consider upgrading
  via https://rimuhosting.com/cp or stop some services to clear more memory
"
    exit 1
  fi

  # detect distro and release
  if [ -e /etc/redhat-release ]; then
      DISTRO=( `grep release /etc/redhat-release | awk '{print $1}'` )
      RELEASE=( `grep release /etc/redhat-release | awk '{print $3}' | cut -d. -f1` )
  elif [ -e /etc/debian_version ]; then
      if ( ! which lsb_release >/dev/null ); then
          echolog "  ...installing 'lsb_release' command"
          apt-get -y -qq install lsb-release  >> /dev/null 2>&1
          if [[ $? -ne 0 ]]; then ERRORMSG="Error: installing lsb_release package failed"; return 1; fi
      fi
      DISTRO=$( lsb_release -is )
      RELEASE=$( lsb_release -cs )
  else
      echo "! Running on unknown distro, some features may not work as expected"
  fi
  [[ -z "$DISTRO" ]] && echo "! Warning: Was not able to identify distribution"
  [[ -z "$RELEASE" ]] && echo "! Warning: Was not able to identify release"


  echo "* Installing Atlasian Confluence Wiki"

  [ -e /etc/profile.d/java.sh ] && source /etc/profile.d/java.sh
  if [[ ! $(which java 2>/dev/null) ]]; then
    if [[ -n "${NOJAVA}" ]]; then
      ERRORMSG="java not found in the system path, aborting due to --nojavainstall command line option"
      return 1
    fi
    wget -q http://proj.ri.mu/installjava.sh
    bash installjava.sh
    rm -f installjava.sh
  fi
  echo "  ...verifying java runtime installed"
  [ -e /etc/profile.d/java.sh ] && source /etc/profile.d/java.sh
  if [[ ! $(which java 2>/dev/null) ]]; then
    echo "     java install not found"
    ERRORMSG="java not found in the system path, check manually to see why? Try the script at http://proj.ri.mu/installjava.sh?"
    return 1
  else
    echo "     java install verified"
  fi

  if [ -z ${NOMYSQL} ]; then
    echo "  ...verifying mysql installation"
    if [[ $(ps auxf | grep -v grep | grep -c mysql) -gt 0 && -e /root/.mysqlp ]]; then
      echo "     mysql already running"
    else
      wget ${WGET_OPTS} http://proj.ri.mu/installmysql.sh
      bash installmysql.sh
      rm -f installmysql.sh
      if [ $? -ne 0 ]; then
        ERRORMSG="failed installing/configuring mysql"
        return 1
      fi
    fi

    # catchall in case something wierd happened
    if [ $(ps auxf | grep -v grep | grep -c mysql) -eq 0 ]; then
      ERRORMSG="It looks like mysql setup failed. Consider calling this script
  with the --nomysql option if you want to skip this step.
"
      return 1
    fi
  
    while ! mysql -u $DBUSER -p$DBPASS -e "USE ${DBNAME}" >> "${DEBUG_LOG}" 2>&1; do
      if ! mysql -u root -p$(cat /root/.mysqlp) -e "USE mysql" >> "${DEBUG_LOG}" 2>&1; then
        ERRORMSG="unable to verify mysql root login, consider adding root database password into /root/.mysqlp ?"
        return 1
      fi
      echo "  ...creating confluence mysql database: "
      echo -n "     database "
      if mysql -u root -p$(cat /root/.mysqlp) -e "USE $DBNAME" >> "${DEBUG_LOG}" 2>&1; then
        echo " warning, already exists"
      elif ! mysql -u root -p$(cat /root/.mysqlp) -e "CREATE DATABASE ${DBNAME}" >> "${DEBUG_LOG}" 2>&1; then
        ERRORMSG="failed adding mysql confluence database"
        return 1
      else 
        echo ok
      fi
      echo -n "     user "
      mysql -u root -p$(cat /root/.mysqlp) -e "REVOKE ALL ON ${DBNAME}.* FROM '${DBUSER}'@'localhost'" >> "${DEBUG_LOG}" 2>&1
      if ! mysql -u root -p$(cat /root/.mysqlp) -e "GRANT ALL ON ${DBNAME}.* TO '${DBUSER}'@'localhost' IDENTIFIED BY '${DBPASS}'" >> "${DEBUG_LOG}" 2>&1; then
        ERRORMSG="failed adding mysql confluence user"
        return 1
      else
        echo ok
      fi
      echo -n "     privileges "
      mysql -u root -p$(cat /root/.mysqlp) -e "FLUSH PRIVILEGES" >> "${DEBUG_LOG}" 2>&1
      echo ok
    done

    echo -n "  ...verifying confluence mysql database: "
    if mysql -u$DBUSER -p$DBPASS -e "USE ${DBNAME}" >> "${DEBUG_LOG}" 2>&1; then
      echo ok
    else 
      echo bad 
      ERRORMSG="failed testing mysql confluence database/user"
      return 1
    fi

    # only do here since it may have performance impact for generalised setups
    echo "  ...tweaking mysql, forcing innodb tables and READ-COMMITED transactions"
    if [ -e /etc/mysql/conf.d/ ]; then
      echo "[mysqld]
transaction_isolation=READ-COMMITTED
default-storage-engine=INNODB
max_allowed_packet=32M
  " > /etc/mysql/conf.d/confluence.cnf
    else
      myconf="/etc/my.cnf"
      [ -e /etc/mysql/my.cnf ] &&  myconf="/etc/mysql/my.cnf"
      sed -i '[mysqld]' '[mysqld]\ntransaction_isolation=READ-COMMITTED' -- $myconf
      sed -i "s/max_allowed_packet=1M/max_allowed_packet=32M/" $myconf
    fi

    [[ -e /etc/init.d/mysqld ]] && MYINITSCRIPT="/etc/init.d/mysqld"
    [[ -e /etc/init.d/mysql ]] && MYINITSCRIPT="/etc/init.d/mysql"
    # fix for rimuhosting.com disabled mysql server script in ubuntu lucid
    [[ -e /etc/init/mysql.conf.disabled ]] && mv /etc/init/mysql.conf{.disabled,}
    [[ -e /etc/init/mysql ]] && MYINITSCRIPT="service mysql"
    if [[ -z $MYINITSCRIPT ]]; then
      ERRORMSG="unable to determine MySQL startup script, this should not happen (BUG)"
      return 1
    fi
    $MYINITSCRIPT restart >> $DEBUG_LOG 2>&1  
  fi

  if [ ! -e $(basename ${FILE_SOURCE}) ]; then
    echo "  ...grabbing install file. Please be patient"
    wget ${WGET_OPTS} ${FILE_SOURCE}
  else
    echo "  ...using pre-downloaded install source file"
  fi

  echo "  ...expanding install file. Please be patient"
  tar -xvzf $(basename ${FILE_SOURCE}) >> ${DEBUG_LOG} 2>&1

  echo "  ...moving install files to the right location"
  mv "$(basename ${FILE_SOURCE} .tar.gz)" "${INSTALL_LOC}"

  echo "  ...creating data folder ${DATADIR} and setting in confluence configuration"
  mkdir -p "${DATADIR}"
  echo "
confluence.home=${DATADIR}" >> "${INSTALL_LOC}/confluence/WEB-INF/classes/confluence-init.properties"

  echo "  ...setting custom ports and reducing exposure"
  sed -i "s|ort=\"8443\" |ort=\"${PORT_PREFIX}43\" |" $INSTALL_LOC/conf/server.xml
  sed -i "s|ort=\"8090\" |ort=\"${PORT_PREFIX}90\" |" $INSTALL_LOC/conf/server.xml
  sed -i "s|ort=\"8000\" |ort=\"${PORT_PREFIX}00\" address=\"127.0.0.1\" |" $INSTALL_LOC/conf/server.xml

  echo "  ...setting up application user"
  # create tomcat user and group if they do not exist
  if [[ $(id ${APPUSER} 2>&1 | grep -c "No such user") -gt "0" ]]; then
    echo "  ...configuring service user and group"
    if [[ $DISTRO == "Debian" || $DISTRO == "Ubuntu" ]]; then
      adduser --system --group ${APPUSER} --home ${INSTALL_LOC}  >> ${DEBUG_LOG} 2>&1
    elif [[ $DISTRO == "CentOS" || $DISTRO == "RHEL" || $DISTRO == "Fedora" ]]; then
      groupadd -r -f ${APPUSER} >> ${DEBUG_LOG} 2>&1
      useradd -r -s /sbin/nologin -d $INSTALL_LOC -g ${APPUSER} ${APPUSER}  >> ${DEBUG_LOG} 2>&1
    else
      echo "Warning: Distribution not recognised, you may need to configure the"
      echo "         Confluence user and group manually. Attempting to perform this"
      echo "         anyway"
      groupadd ${APPUSER} >> ${DEBUG_LOG} 2>&1
      useradd -s /sbin/nologin -d $INSTALLTARGET -g tomcat tomcat  >> ${DEBUG_LOG} 2>&1
    fi
  fi
  if [[ $(id $APPUSER 2>&1 | grep -c "No such user") -gt 0 ]]; then
    ERRORMSG="failed adding confluence user '$APPUSER', bailing. Check your system?"
    return 1
  fi

  # set tomcat files to be available under the right user
  echo "  ...fixing confluence folder permssions"
  chown -R ${APPUSER}:${APPUSER} ${INSTALL_LOC}
  chown -R ${APPUSER}:${APPUSER} ${DATADIR}

  echo "  ...adding startup script"
  wget ${WGET_OPTS} http://proj.ri.mu/confluence.init.sysv
  mv confluence.init.sysv ${INITSCRIPT}
  chmod +x ${INITSCRIPT}
  sed -i "s/USER=confluence/USER=${APPUSER}/" ${INITSCRIPT}
  sed -i "s/port=\"9980\"/port=\"${PORT_PREFIX}90\"/" ${INITSCRIPT}

  if [ -n "${RUNONSTARTUP}" ]; then
    echo "  ...setting confluence to run on system startup"
    if [ -e /etc/debian_version ]; then
      update-rc.d "${APPNAME}" defaults >> ${DEBUG_LOG} 2>&1
    else
      chkconfig --add "${APPNAME}" >> ${DEBUG_LOG} 2>&1
    fi
  fi

  echo "  ...attempt to start Confluence service"
  $INITSCRIPT restart  >> ${DEBUG_LOG} 2>&1

  echo -n "  ...pausing for Confluence service to settle: "
  for i in $(seq 10 -1 1); do sleep 1; echo -n " $i"; done;
  echo

  echo -n "  ...verifying service status"
  if [[ $($INITSCRIPT status | grep -c 'PIDs') < 1 ]]; then
    echo ", failed"
    echo "! Error: Confluence not started cleanly, please contact $SUPPORT_EMAIL to debug"
  else
    ipaddr="$(ifconfig eth0 | grep "inet addr:" | awk '{print $2}' | cut -d: -f2)"
    echo ", ok"
    echo "* Confluence is now installed and should be visible on http://${ipaddr}:${PORT_PREFIX}90"
    echo "  You will need to complete the web based setup wizard there."
    if [ -z ${NOMYSQL} ]; then
      echo "  Select 'Production Installation' and pass in the below details if you want Confluence to use a"
      echo "  direct connection to the MySQL database. Or see the URL to learn how to configure a datasource"
      echo "  ref http://confluence.atlassian.com/display/DOC/Configuring+a+MySQL+Datasource+in+Apache+Tomcat"
      echo "  mysql database name = $DBNAME, user = $DBUSER, password = $DBPASS"
    fi
  fi

  return 0
}


parsecommandline $*
if [[ $? -ne 0 ]]; then
  echo
  version
  usage
  echolog "! Error from command: $ERRORMSG"
  echo
  exit 1
fi
[[ -z $NOPROMPT && "$CALLER" == "-bash" ]] && version

installconfluence
if [[ $? -ne 0 ]]; then
#   echo
  echolog "! Error from installer: $ERRORMSG"
  echo
  exit 1
fi


