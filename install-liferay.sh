#!/bin/bash

##
## $Id: installliferay.sh 291 2013-02-20 03:29:39Z root $
##
## Liferay install script, &copy;rimuhosting.com
## updated from 4.2 GA to 5.2 by Glenn Enright 23/6/09
## updated from 5 to generic latest version 6 or 5  - ge 12-Oct-2010

## == set liferay version and a couple of handy vars
SCRIPTVERSION="20101016"
MAJORVERSION="6"
INSTALLVERSION=
WGETURL=
MEMORYREQUIRED="900"
APPNAME="liferay"
INSTALLDEST="/usr/local/${APPNAME}"
DATE=$(date +%s)

###
# Function: version
# Tell us what version the script is... duh :)
#
function version {
    echo "** Liferay + Tomcat bundle install script
   Version $SCRIPTVERSION
   Copyright RimuHosting.com
   Tested with Ubuntu Lucid, Debian Lenny and CentOS5"
}


###
# Function: usage
# Handy function to tell users how. update it you change parsecommandline
#
function usage {
  echo "
   Usage: $0 [--version <5 or 6>]
"
}


###
# Function: parsecommandline
# Take parameters as given on command line and set those up so we can do
# cooler stuff, or complain that nothing will work. Set some reasonable
# defaults so we dont have to type so much.
#
function parsecommandline {
  echo " * Checking command line argumenets"
  while [ -n "$1" ]; do
    PARAM=$1
    case "$1" in
    --version | -v)
      shift
      if [[ -z "$1" ]]; then
        echo "Exiting: $PARAM given without version (use 5 or 6)"  >&2
        usage
        exit 1
      elif [[ "$1" != "5" && "$1" != "6" ]]; then
        echo "Exiting: $PARAM has an unsupported version '$1', use 5 or 6 instead"  >&2
        usage
        exit 1
      fi
      MAJORVERSION="$1"
      ;;
    *)
      echo "Exiting: unrecognised paramter '$PARAM'"  >&2
      usage
      exit 1;
      ;;
    esac
    shift
  done

  # set env for correct installation of required version
  if [ "${MAJORVERSION}" = "6" ]; then
    echo "   Scraping the latest version, 6.0.5 at time of writing. Please be patient"
    # <a href="/projects/lportal/files/latest/download?source=files" title="/Liferay Portal/6.1.1 GA2/liferay-portal-tomcat-6.1.1-ce-ga2-20120731132656558.zip: released on 2012-08-01 02:49:01 UTC">
    line=$(wget --quiet http://sourceforge.net/projects/lportal/files -O - 2>&1 | grep -A 1 'latest version?' | grep 'href')
    # 6.1.1 GA2
    INSTALLVERSION=$(echo ${line#*title=} | cut -d/ -f3)
    #WGETURL="http://downloads.sourceforge.net/project/lportal/Liferay Portal/${INSTALLVERSION}/liferay-portal-tomcat-${INSTALLVERSION}.zip"
    # /Liferay Portal/6.1.1 GA2/liferay-portal-tomcat-6.1.1-ce-ga2-20120731132656558.zip
    URI=$(echo ${line#*title=}  | sed s'/"//' | sed 's/: .*//')
    WGETURL="http://downloads.sourceforge.net/project/lportal$URI"
  else
    # version includes tomcat version
    INSTALLVERSION=5.2.3
    WGETURL="http://downloads.sourceforge.net/project/lportal/Liferay Portal/${INSTALLVERSION}/liferay-portal-tomcat-6.0-${INSTALLVERSION}.zip"
  fi
  echo "   Using ${INSTALLVERSION}"
}


###
# Function: installreqs
# make sure we have some essentials installed, including unzip,
# mysql-server, java, etc
#
function installreqs {
  echo " * Making sure the package-manager is up to date"
  apt-get -qq update

  echo " * Checking pre-install requirements"

  echo -n "   Reserved memory:        "
  MEMFOUND=$(free -m | grep 'buffers/cache' | awk '{print $4}')
  if [ "${MEMFOUND}" -lt "${MEMORYREQUIRED}" ]; then
    echo "nok. Only ${MEMFOUND}MB free."
    echo "
Minimum ${MEMORYREQUIRED}MB recomended for safe operation. Consider
upgrading via https://rimuhosting.com/cp or stop some services to clear
more memory
"
    free -m
    exit 1
  else
    echo "ok. ${MEMFOUND}MB available, should be fine"
  fi

  [ -e /etc/profile.d/java.sh ] && source /etc/profile.d/java.sh
  if [[ ! $(which java) ]]; then
    echo "   Java:                   Not found in the system path, please install that before proceeding..."
    exit 1
  fi

  if [[ ! $(which unzip) ]]; then
    echo "   unzip:                  Command not found, installing as prerequisite"
    apt-get -y -qq install unzip
  fi

  if [[ ! $(which convert) ]]; then
    echo "   ImageMagick:            Tools not found, installing as prerequisite"
    if [ -e /etc/redhat-release ]; then
      apt-get -y -qq install ImageMagick
    else
      apt-get -y -qq install imagemagick
    fi
  fi

  if [[ ! $(which soffice) ]]; then
    echo "   OpenOffice (headless):  Command not found, installing as prerequisite"
    apt-get -y -qq install openoffice.org-headless
  fi

  if [[ ! $(which mysqld_safe) ]]; then
    echo "   Mysql Server:           Service not found, installing as prerequisite"
    apt-get -y -qq install mysql-server
  fi

  if [[ -L ${INSTALLDEST} || -e ${INSTALLDEST} ]]; then
    echo "   Existing installs:      nok"
    echo "
Possible existing liferay install found in ${INSTALLDEST}"
    read -p "Press Ctl-C to exit or any key to move that out of the way and make a clean install?"
    echo
    echo "   Attempting to disable that"
    /etc/init.d/${APPNAME} stop >> /dev/null 2>&1
  fi

  echo -n "   Conflicting services:  "
  if [ ! $(netstat -plnt | grep -c ':8080' ) ]; then
    echo "discovered"
    echo "
Make sure that any java services (eg stadard tomcat) which are using ports
between 8000 and 8999 are moved out of the way or stopped before proceeding,
liferay needs to own these else configuration can get awkward
"
    read -p "Press Ctl-C to exit or any other key to continue anyway"
  else
    echo "none found, proceeding with a fresh install"
  fi

}

function setup_openoffice {
  echo " * Setting up OpenOffice.org headless service"
  SCRIPTNAME="/etc/init.d/openoffice-headless"
  wget --quiet http://proj.ri.mu/openoffice-headless.init -O - > ${SCRIPTNAME}
  chmod 0755 ${SCRIPTNAME}
  update-rc.d $(basename ${SCRIPTNAME}) defaults  >> /dev/null 2>&1
  ${SCRIPTNAME} start >> /dev/null 2>&1
}


###
# Function: setup_mysql
# its not worth running if mysql doesnt exist
#
function setup_mysql {
  echo " * Configuring mysql"
  if [ -e /etc/init.d/mysqld ]; then
    mysql=/etc/init.d/mysqld
  else
    mysql=/etc/init.d/mysql
  fi

  # fix for rimuhosting.com disabled mysql server script in ubuntu lucid
  if [ -e /etc/init/mysql.conf.disabled ]; then mv /etc/init/mysql.conf{.disabled,}; fi

  # dont bother adding mysql support if it really (somehow) doesnt exist,
  # then we might as well revert to low qual hsqldb
  if [ ! -x $mysql ]; then
    echo "   No mysql serivce script found. Unable to manage required service"
    exit 1
  else
    $mysql start >> /dev/null 2>&1
  fi

  echo " * Working out the MySQL administrative password..."
  mysqluser=root
  mysqlpass=""
  overpass="/root/.mysqlp"

  if [ -e /etc/psa/.psa.shadow ]; then
    echo "   Found Plesk install, getting alternate MySQL configuration"
    mysqlpass=$(cat /etc/psa/.psa.shadow)
    mysqluser=admin
  fi
  if [ -e ${overpass} ]; then
    echo "   Found possible overide password in ${overpass}, using that"
    mysqlpass=$(cat ${overpass})
  fi

  if [ -z "$mysqlpass" -a ! -e ${overpass} ]; then
    echo "   Not able to automatically determine password..."
  fi
  while [ -z "$mysqlpass" -a ! -e ${overpass} ]; do
    echo -n "   Enter new password now >> "
    read mysqlpass
    if [ ! -z "$mysqlpass" ]; then
      echo $mysqlpass > ${overpass}
      chmod og= ${overpass}
    fi
  done

  mysqladmin -u $mysqluser password "$mysqlpass" 2>/dev/null
  mysql -u $mysqluser -p$mysqlpass -e "use mysql;" 2> /dev/null
  if [ $? -ne 0 ]; then
    echo "   Unable to login to MySQL."
    echo "
Please verify or otherwise set the root password manually and add that to
${overpass} before rerunning this script.
"
    exit 1
  fi
  export mysqluser mysqlpass
}


function setup_liferay {
  echo " * Installing Liferay files"

  [ -L "${INSTALLDEST}" ] && rm -f "${INSTALLDEST}"
  if [ -e "${INSTALLDEST}" ]; then
    echo "   Backing up existing liferay installation to ${INSTALLDEST}.pre${DATE}"
    [ -e "${INSTALLDEST}" ] && mv "${INSTALLDEST}" "${INSTALLDEST}.pre${DATE}"
  fi

  echo "   Grabbing liferay installation files"
  cd $(dirname ${INSTALLDEST})
  wget -c --quiet "${WGETURL}"
  [ $? -ne 0 ]  && echo "Failed getting ${WGETURL}" >&2 && return 1 

  echo "   Unpacking liferay installation files"
  zipfile=$(echo "${WGETURL}" | sed 's/.*\///')
  #zipfile=$(echo "${WGETURL}" | cut -d/ -f 8)
  [ -d liferay.unzip.tomcat ] && rm -rf liferay.unzip.tomcat
  unzip -q "${zipfile}" -d liferay.unzip.tomcat
  [ $? -ne 0 ]  && echo "Failed unzipping $zipfile" >&2 && return 1 
  mv liferay.unzip.tomcat/* ${INSTALLDEST}
  [ $? -ne 0 ]  && echo "Failed moving liferay's tomcat to $INSTALLDEST" >&2 && return 1 
}

function setup_liferaydb {
  echo " * Liferay database import and mysql post configuration"

  echo "   Creating liferay mysql db and user"
  lifepassfile="/root/.liferayp"
  lifepass=
  if [ -e ${lifepassfile} ] ; then
    echo "   Using stored password"
    lifepass=$(cat ${lifepassfile})
  else
    echo "   Not able to automatically determine password..."
  fi
  while [ -z "$lifepass" ]; do
    echo -n "   Enter new Liferay database password now >> "
    read lifepass
    if [ ! -z "$lifepass" ]; then
      echo $lifepass > ${lifepassfile}
      chmod og= ${lifepassfile}
    fi
  done

  mysql -u "${mysqluser}" -p"${mysqlpass}" -e "use lportal;" 2> /dev/null
  if [ $? -ne 0 ]; then
    # Database doesn't exist. Create it.
    mysql -u ${mysqluser} -p${mysqlpass} -e "create database lportal character set utf8;"
    mysql -u ${mysqluser} -p${mysqlpass} -e "GRANT ALL ON lportal.* TO 'lportal'@'localhost' identified by '$lifepass';"
    mysql -u ${mysqluser} -p${mysqlpass} -e "flush privileges;"
  else
    echo "
Database 'lportal' already exists. You'll need to check manually
that your lportal database and username match the details in
/usr/local/liferay/conf/Catalina/localhost/ROOT.xml.
"
    return
  fi

  echo "   Grab and unpack table initialisation files"
  cd "$(dirname ${INSTALLDEST})"
  SQLURL=$(echo $WGETURL | sed 's/tomcat/sql/')
  wget -c --quiet "$SQLURL"
  [ $? -ne 0 ] && echo "Failed getting SQL" >&2 && return 1
  [ -d liferay.unzip.sql ] && rm -rf liferay.unzip.sql
  unzip -o -qq "$(echo $SQLURL | sed 's/.*\///')" -d liferay.unzip.sql
  [ $? -ne 0 ] && echo "Failed unzipping SQL" >&2 && return 1
  echo "   Initialise the liferay database"
  FILE=$(find liferay.unzip.sql -name 'create-minimal-mysql.sql' | head -n 1)
  mysql -u lportal -p$(cat ${lifepassfile}) lportal < "$FILE"
  [ $? -ne 0 ] && echo "Failed running SQL" >&2 && return 1

  echo " * Configuring liferay to use mysql"
  mkdir -p "${INSTALLDEST}/webapps/ROOT/WEB-INF/classes"
  #conf="${INSTALLDEST}/webapps/ROOT/WEB-INF/classes/portal-ext.properties"
  conf="${INSTALLDEST}/portal-ext.properties"
  touch $conf
  echo "jdbc.default.driverClassName=com.mysql.jdbc.Driver" > $conf
  echo "jdbc.default.url=jdbc:mysql://localhost/lportal?useUnicode=true&characterEncoding=UTF-8&useFastDateParsing=false" >> $conf
  echo "jdbc.default.username=lportal" >> $conf
  echo "jdbc.default.password=$(cat ${lifepassfile})" >> $conf
}


###
# Function: setperms
# configure user and file permissions
# assumes installtarget already exists
#
function setup_permissions {
  echo " * Setting up service permissions"

  # create tomcat user and group if they doesnt already exist, and secure them
  echo "   Configuring service user and group"
  if [ -e /etc/debian_version ]; then
    adduser --system --group "${APPNAME}" --home "${INSTALLDEST}"
  elif [ -e /etc/redhat-release ]; then
    groupadd -r -f "${APPNAME}"
    useradd -r -s /sbin/nologin -d "${INSTALLDEST}" -g "${APPNAME}" "${APPNAME}"
  else
    echo "
Warning: Distribution not recognised, you may need to configure the ${APPNAME}
user and group manually. Attempting to perform this anyway.
"
    groupadd "${APPNAME}"
    useradd -s /sbin/nologin -d "${INSTALLDEST}" -g "${APPNAME}" "${APPNAME}"
  fi

  # set tomcat files to be available under the right user
  echo "   Enforcing ${APPNAME} file permssions"
  chown -R ${APPNAME}:${APPNAME} "${INSTALLDEST}"
  chown -R ${APPNAME}:${APPNAME} "${INSTALLDEST}/"
}

function setup_post {
  echo " * Runing post install tasks"
  tomcatloc="${INSTALLDEST}"/$(ls "${INSTALLDEST}" | grep tomcat)
  #tomcatloc="${INSTALLDEST}"
  echo "   Secure ajp port to localhost only"
  sed -i 's/port="8009" protocol/port="8009" address="127.0.0.1" protocol/' ${tomcatloc}/conf/server.xml

  echo "   Removing demo apps"
  mkdir -p "${tomcatloc}/webapps.removed"
  mv "${tomcatloc}"/webapps/sevencogs* "${tomcatloc}"/webapps.removed

  ## == install an init script and start liferay
  echo "   Providing an init script for the liferay service and starting that"
  wget --quiet -O /etc/init.d/"${APPNAME}" "http://proj.ri.mu/javainitscript"
  chmod +x /etc/init.d/"${APPNAME}"
  /etc/init.d/"${APPNAME}" start >> /dev/null 2>&1
  if [ -e /etc/redhat-release ]; then
    chkconfig "${APPNAME}" on
  else
    update-rc.d "${APPNAME}" defaults
  fi

  IP=$(ifconfig | grep --after-context=1 "eth0 " | grep inet | cut -d: -f2 | cut -f1 -d' ')
  sleep 10
  wget -O - "http://${IP}:8080" --server-response  2>&1 | grep -qai 'onLoad'
  if [ $? -eq 0 ]; then
    echo "Looks like Liferay is loading correctly, view it at http://${IP}:8080"
    echo "Log in as test@liferay.com, with password test. And change that as soon as possible."
  else
    echo "There could be a problem with Liferay, it did not load as expected"
    echo "Double check http://${IP}:8080"
    echo "If it is loading then log in as test@liferay.com, with password test. And change that as soon as possible."
  fi
}

version
parsecommandline $*
installreqs
setup_openoffice
setup_mysql
setup_liferay
setup_liferaydb
setup_permissions
setup_post

