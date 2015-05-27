#!/bin/bash

# Copyright Rimuhosting.com
# updated 18th Dec 2009 by Glenn Enright
# updated 18-Jan-2011 by Peter Bryant and Glenn Enright for Tomcat 7 (issue #600)
# TODO mysql integration?
# TODO restore option?

# target for installation. remove any trailing /s
DEFAULTINSTALLTARGET="/usr/local/tomcat"
INSTALLTARGET=
INITSCRIPT="/etc/init.d/tomcat"

DEBUG_WORLD=${DEBUG_WORLD:-false} # used by prepserver, or you can define as an export :)
DEBUG_INSTALLTOMCAT=${DEBUG_INSTALLTOMCAT:-$DEBUG_WORLD} # used to reveal extra debugging message

# default values
ERRORMSG=
MVDIRSTAMP="old.$(date +%s)"
MVDIRNAME=
MAJORTOMCATVERSION=7
SETUP=standard
NOPROMPT=
NOMIGRATE=
NOJAVA=
REMEXAMPLE=
DISABLEUNPACKWARS=
REDUCESPARETHREADS=
REMADMIN=
RUNONSTARTUP=
URIUTF8=

###
# Function: version
# Tell us what version the script is... duh :)
#
function version {
    echo "
 $0 (v3.2 $Id: installtomcat.sh 388 2014-07-01 01:00:05Z root $)
 Copyright Rimuhosting.com
"
}


###
# Function: usage
# Handy function to tell users whats what
# TODO: add boilerplate?
#
function usage {
  echo " Usage: $0 [--version (6 | 7 | 8)] [(setup type)] [--noprompt]
      [--installtarget (folder)] [--skip-migrate-webapps] [--skip-java]
      [--remexample (y or n) --disableunpackwars (y or n)
      --reducesparethreads (y or n) --remadmin (y or n)
      --runonstartup (y or n) --uriutf8 (y or n)]

  Option notes:
  --noprompt      makes safe assumptions and runs without user interaction
  --installtarget optional install location (default is $DEFAULTINSTALLTARGET)
  --skip-migrate-webapps
                  dont port customer webapps from existing install

  Setting the y/n options forces a custom setup.

  Setup types currently available
  * custom - customised installation, will prompt for options
  * standard - rimuhosting recomended setup (default)
  * hs - restrictive, used for administrative purposes
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
    custom | standard | hs)
      SETUP=$PARAM
      ;;
    --version | -v)
      shift
      if [[ -z "$1" ]]; then
        echo "Error: $PARAM given without version, use 6, 7 or 8"
        usage
        exit 1
      elif [[ "$1" != "6" && "$1" != "7" && "$1" != "8" ]]; then
        ERRORMSG="$PARAM given with unsupported version '$1', use 6, 7 or 8"
        return 1
      fi
      MAJORTOMCATVERSION=$1
      ;;
    --noprompt)
      NOPROMPT=n
      ;;
    --installtarget)
      shift
      if [[ -e "$1" && ! -d "$1" ]]; then
        ERRORMSG="target already $1 exists but is not a folder"
        return 1
      fi
      if [[ $(echo $1 | grep ^/ ) == "0" ]]; then
        ERRORMSG="please pass in --installtarget as an absolute folder (eg: $DEFAULTINSTALLTARGET, gave $1)"
        return 1
      fi
      INSTALLTARGET="$1"
      SETUP='custom'
      ;;
    --remexample)
      shift
      if [[ "$1" != "y" &&  "$1" != "n" ]]; then
        ERRORMSG="$PARAM given with unexpected or missing value, use y or n"
        return 1
      fi
      REMEXAMPLE=$1
      SETUP='custom'
      ;;
    --disableunpackwars)
      shift
      if [[ ! "$1" == "y" || "$1" == "n" ]]; then
        ERRORMSG="$PARAM given with unexpected or missing value, use y or n"
        return 1
      fi
      DISABLEUNPACKWARS=$1
      SETUP='custom'
      ;;
    --reducesparethreads)
      shift
      if [[ ! "$1" == "y" || "$1" == "n" ]]; then
        ERRORMSG="$PARAM given with unexpected or missing value, use y or n"
        return 1
      fi
      REDUCESPARETHREADS=$1
      SETUP='custom'
      ;;
    --remadmin)
      shift
      if [[ ! "$1" == "y" || "$1" == "n" ]]; then
        ERRORMSG="$PARAM given with unexpected or missing value, use y or n"
        return 1
      fi
      REMADMIN=$1
      SETUP='custom'
      ;;
    --runonstartup)
      shift
      if [[ ! "$1" == "y" || "$1" == "n" ]]; then
        ERRORMSG="$PARAM given with unexpected or missing value, use y or n"
        return 1
      fi
      RUNONSTARTUP=$1
      SETUP='custom'
      ;;
    --uriutf8)
      shift
      if [[ ! "$1" == "y" || "$1" == "n" ]]; then
        ERRORMSG="$PARAM given with unexpected or missing value, use y or n"
        return 1
      fi
      URIUTF8=$1
      SETUP='custom'
      ;;
    --skip-migrate-webapps)
      NOMIGRATE=y
      ;;
    --skip-java)
      NOJAVA=y
      ;;
    -h|help|-help|--help|?|-?|--?)
      version
      usage
      exit 1;
      ;;
    *)
      ERRORMSG="unrecognised paramter '$PARAM'"
      return 1;
      ;;
    esac
    shift
  done

  INSTALLTARGET=${INSTALLTARGET:-$DEFAULTINSTALLTARGET}

  # set boundaries for the install type
  if [ "$SETUP" = "custom" ]; then
    # logic placeholder munge, dont combine
    if [[ ! -z $NOPROMPT ]]; then
      echo "Error: custom setup activated but conflicts with --noprompt mode. Bailing"
      exit 1
    fi
  elif [ "$SETUP" = "standard" ]; then
    REMEXAMPLE=y
    DISABLEUNPACKWARS=n
    REDUCESPARETHREADS=y
    REMADMIN=y
    RUNONSTARTUP=y
    URIUTF8=y
  elif [ "$SETUP" = "hs" ]; then
    REMEXAMPLE=y
    DISABLEUNPACKWARS=y
    REDUCESPARETHREADS=y
    REMADMIN=y
    RUNONSTARTUP=y
    URIUTF8=y
    NOMIGRATE=y
  else
    echo "Error: unrecognized setup type '$1'.  Expecting one of 'custom', 'standard', or 'hs'"
    exit 1
  fi

  # detect distro and release
  if [ -e /etc/redhat-release ]; then
      DISTRO=( `grep release /etc/redhat-release | awk '{print $1}'` )
      RELEASE=( `grep release /etc/redhat-release | awk '{print $3}' | cut -d. -f1` )
  elif [ -e /etc/debian_version ]; then
      if ( ! which lsb_release >/dev/null ); then
          echo "  ...installing 'lsb_release' command"
          apt-get -y -qq install lsb-release  >> /dev/null 2>&1
          if [[ $? -ne 0 ]]; then echo "Error: installing lsb_release package failed"; exit 1; fi
      fi
      DISTRO=$( lsb_release -is )
      RELEASE=$( lsb_release -cs )
  else
      echo "! Running on unknown distro, some features may not work as expected"
  fi
  [[ -z "$DISTRO" ]] && echo "! Warning: Was not able to identify distribution"
  [[ -z "$RELEASE" ]] && echo "! Warning: Was not able to identify release"

  # set env for correct installation of required version
  tsrc="http://www.apache.org/dist/tomcat/tomcat-$MAJORTOMCATVERSION"
  export tomcatversion=$(wget -qO- $tsrc | grep "v$MAJORTOMCATVERSION." | sed 's/<[^>]*>//g' | awk '{print $1}' | sed 's/v//;s/\///' | sort -n | tail -n1)
  if [[ -z $tomcatversion ]]; then 
    # hardcode version if we couldnt guess it
    [[ "$MAJORTOMCATVERSION" = "6" ]] && export tomcatversion=6.0.39
    [[ "$MAJORTOMCATVERSION" = "7" ]] && export tomcatversion=7.0.50
    [[ "$MAJORTOMCATVERSION" = "8" ]] && export tomcatversion=8.0.3
    echo "! Failed to grep latest tomcat version, using hardcoded version, may be old"
  fi
  tomcaturl="$tsrc/v$tomcatversion/bin/apache-tomcat-$tomcatversion.tar.gz"
}


###
# Function: installreqs
# Make sure any essential components need for this script or the tomcat install are available
#
function installreqs {
  echo "* Verifying installation requirements"
  if [[ $(id -u) != "0" ]] ; then
    ERRORMSG="You should be root to run this (e.g. sudo $0 $* ) "
    return 1
  fi

  echo "  ...checking for existing tomcat installations"
  if [[ -d $INSTALLTARGET && $(ls -1 "$INSTALLTARGET" | wc -l) != 0 ]]; then
    # only care if folder is non-empty
    if [[ -z $NOPROMPT ]]; then
      echo "! Target $INSTALLTARGET exists, press Ctrl-C to quit or Enter to continue and backup those files... "
      read -s
    else
      ERRORMSG="$INSTALLTARGET not empty, called with --noprompt so aborting to avoid making a mess"
      return 1
    fi
  fi

  # TODO add java presence install
  [[ -e /etc/profile.d/java.sh ]] && source /etc/profile.d/java.sh
  if [[ ! $(which java 2>/dev/null) ]]; then
    if [[ -n "$NOJAVA" ]]; then
      ERRORMSG="java not found in the system path, install that before proceeding?"
      return 1
    fi
    wget -q http://downloads.rimuhosting.com/installjava.sh
    bash installjava.sh
    rm -f installjava.sh
    # add to path and set java_home
    source /etc/profile.d/java.sh
  fi
  if [[ $(java -version 2>&1 | egrep -c '1.6|1.7|1.8' ) < 1 && "$MAJORTOMCATVERSION" = "7" ]]; then
    ERRORMSG="Tomcat 7 requires Java SE 6.0 or later. please install that before proceeding.
Try the script at http://proj.ri.mu/installjava.sh ?"
    return 1
  fi

}



###
# Function: installtomcat
# Actually do the tomcat package install
#
function installtomcat {
  echo "* Installing Tomcat"

  # remove existing (old or conflicting) init scripts to backup location
  MVDIRNAME="$INSTALLTARGET.$MVDIRSTAMP"
  tomcatscripts=$(find /etc/init.d/ -print | xargs grep -c $INSTALLTARGET | grep -v ":0$" | cut -d: -f1)
  if [ ! -z "$tomcatscripts" ]; then
    for i in $tomcatscripts; do
      echo "  ...attempting to stop existing tomcat instance managed by $i to avoid conflicts"
      $i stop  >> /dev/null 2>&1
      if [[ $($i status | grep -c 'PIDs') > 0 ]]; then
        ERRORMSG="tomcat not stopped cleanly, this should not happen (BUG)"
        return 1
      fi
    done
    for i in $tomcatscripts; do
      echo "  ...init script $i moved to $(dirname $INSTALLTARGET)/$(basename $i).$MVDIRSTAMP.init"
      mv $i "$(dirname $INSTALLTARGET)/$(basename $i).$MVDIRSTAMP.init"
    done
  fi

  # move old tomcat installs out of the way with a datestamp
  if [ -e $INSTALLTARGET ]; then
    echo "  ...found $INSTALLTARGET, backing up directory to $MVDIRNAME"
    mv "$INSTALLTARGET" "$MVDIRNAME"
  fi

  echo "  ...updating tomcat init script"
  wget --quiet -O - "http://proj.ri.mu/javainitscript" > $INITSCRIPT
  if [ $? -ne 0 ]; then 
    ERRORMSG="failed downloading init script"; 
    [ -e /etc/init.d/ ] && return 1
    echo $ERRORMSG ".  But no /etc/init.d/ so ignoring."
  else 
   chmod +x $INITSCRIPT
  fi

  # make sure the init script is pointing at the right place
  if [[ "$INSTALLTARGET" != "$DEFAULTINSTALLTARGET" ]]; then
    sed -i "s/HOMEDIR=$DEFAULTINSTALLTARGET/HOMEDIR=$INSTALLTARGET/" $INITSCRIPT
  fi

  echo "  ...installing Tomcat $MAJORTOMCATVERSION package to $INSTALLTARGET"
  installtop=$(dirname $INSTALLTARGET)
  cd $installtop
  wget --quiet -O - "$tomcaturl" | tar xz
  if [ $? -ne 0 ]; then ERRORMSG="failed downloading or uncompressing tomcat package"; return 1; fi
  mv "$installtop/apache-tomcat-$tomcatversion" "$INSTALLTARGET"

  # mysql-connector 5.1.13 as at 2010-11-05
  # mail from mercury version hg 292 @ 2010-09-21 as at 2010-11095
  echo -n "  ...installing additional libraries:"
  DIR=$(if [ -e common/lib ] ; then echo common/lib; else echo lib; fi)
  for lib in mysql-connector mail activation; do
    [ -e $DIR/$lib.jar ] && continue
    echo -n " $lib"
    wget --quiet -O - http://downloads.rimuhosting.com/$lib.jar > $INSTALLTARGET/$DIR/$lib.jar
    if [ $? -ne 0 ]; then ERRORMSG="Error: failed downloading library $lib"; return 1; fi
  done
  echo

  # create tomcat user and group if they do not exist
  if [[ $(id tomcat 2>&1 | grep -ic "No such user") -gt "0" ]]; then
    echo "  ...configuring service user and group"
    if [[ $DISTRO == "Debian" || $DISTRO == "Ubuntu" ]]; then
      adduser --system --group tomcat --home $INSTALLTARGET >> /dev/null 2>&1
    elif [[ $DISTRO == "CentOS" || $DISTRO == "RHEL" || $DISTRO == "Fedora" ]]; then
      groupadd -r -f tomcat  >> /dev/null 2>&1
      useradd -r -s /sbin/nologin -d $INSTALLTARGET -g tomcat tomcat >> /dev/null 2>&1
    else
      echo "Warning: Distribution not recognised, you may need to configure the"
      echo "         tomcat user and group manually. Attempting to perform this"
      echo "         anyway"
      groupadd tomcat  >> /dev/null 2>&1
      useradd -s /sbin/nologin -d $INSTALLTARGET -g tomcat tomcat >> /dev/null 2>&1
    fi
  fi
  if [[ $(id tomcat 2>&1 | grep -c "No such user") -gt 0 ]]; then
    ERRORMSG="failed adding tomcat user, bailing. Check your system?"
    return 1
  fi

  # set tomcat files to be available under the right user
  echo "  ...fixing tomcat file permssions"
  if [[ $SETUP != "hs" ]]; then
    chown -R tomcat.tomcat $INSTALLTARGET
    chown -R tomcat.tomcat $INSTALLTARGET/*
    sed -i "s/TOMCAT_USER=root/TOMCAT_USER=tomcat/" $INITSCRIPT
  else
    chown -R root.root $INSTALLTARGET
    chown -R root.root $INSTALLTARGET/*
    sed -i "s/TOMCAT_USER=tomcat/TOMCAT_USER=root/" $INITSCRIPT
  fi

  #for security reasons
  echo "  ...moving non-essential webapps and configs away"
  cd $INSTALLTARGET
  mkdir -p webapps.removed
  if [ -e server/webapps ]; then mv server/webapps webapps.removed/server.webapps; fi
  if [ -e webapps/balancer ]; then mv webapps/balancer webapps/webdav webapps.removed/; fi
  if [ -e webapps/examples ]; then mv webapps/examples webapps.removed/; fi
  if [ -e conf/Catalina/localhost ]; then
    for i in $(ls conf/Catalina/localhost/*.xml); do mv $i webapps.removed/; done
  fi

  # override default memory settings
  echo "  ...configuring default jvm memory constraints"
  echo '#small-ish
#JAVA_OPTS="-Xms16m -Xmx160m -Djava.awt.headless=true"
#debug
#JAVA_OPTS="-Xms16m -XX:MaxPermSize=456m -Xmx764m -Dmail.host=localhost -Djava.awt.headless=true  -Xdebug -Xrunjdwp:transport=dt_socket,address=8000,server=y,suspend=n "
#bigish vm
JAVA_OPTS="-Xms16m -XX:MaxPermSize=456m -Xmx764m -Djava.awt.headless=true "' > $INSTALLTARGET/bin/setenv.sh

  while true; do
    if [ -z "$REDUCESPARETHREADS" ]; then
      echo -n "  Reduce big spare thread count ? [y/n] "
      read REDUCESPARETHREADS
    fi
    if [ "$REDUCESPARETHREADS" = "n" ]; then break; fi
    if [ "$REDUCESPARETHREADS" != "y" ]; then continue; fi
    echo "  ...reducing the number of spare threads"
    if [ ! -e $INSTALLTARGET/conf/server.xml ]; then echo "Error: Somethings not right, $INSTALLTARGET/conf/server.xml expected but not found"; exit 1; fi
    sed -i 's/minSpareThreads="25"/minSpareThreads="1"/g' $INSTALLTARGET/conf/server.xml
    sed -i 's/maxSpareThreads="75"/maxSpareThreads="2"/g' $INSTALLTARGET/conf/server.xml
    sed -i 's/maxSpareThreads="25"/maxSpareThreads="2"/g' $INSTALLTARGET/conf/server.xml
    sed -i 's/maxSpareThreads="150"/maxSpareThreads="2"/g' $INSTALLTARGET/conf/server.xml
    sed -i 's/tcpThreadCount="6"/tcpThreadCount="1"/g' $INSTALLTARGET/conf/server.xml
    sed -i 's/maxThreads="4"/maxThreads="2"/g' -- $INSTALLTARGET/conf/server.xml
    sed -i 's/minSpareThreads="2"/minSpareThreads="1"/g' $INSTALLTARGET/conf/server.xml
    sed -i 's/maxSpareThreads="4"/maxSpareThreads="2"/g' $INSTALLTARGET/conf/server.xml

    # make the selected protocols listen just on the localhost address
    # TODO make this a seperate option?
    echo "  ...restricting exposed ports to improve security"
    sed -i 's/redirectPort="8443" protocol="HTTP\/1.1"/redirectPort="8443" address="127.0.0.1" protocol="HTTP\/1.1"/' $INSTALLTARGET/conf/server.xml
    sed -i 's/Connector port="8009" protocol/Connector port="8009" address="127.0.0.1" protocol/' $INSTALLTARGET/conf/server.xml
    break
  done

  while true; do
    if [ -z "$REMEXAMPLE" ]; then
      echo -n "  Want to remove all the example and doc webapps? [y/n] "
      read REMEXAMPLE
    fi
    if [ "$REMEXAMPLE" = "n" ]; then break; fi
    if [ "$REMEXAMPLE" != "y" ]; then continue; fi
    echo "  ...removing the example webapps"
    applist="webapps/jsp-examples webapps/examples webapps/servlets-examples webapps/tomcat-docs webapps/docs webapps/ROOT"
    for i in $applist; do if [ -e $i ]; then mv $i webapps.removed/; fi; done
    break
  done

  while true; do
    if [ -z "$DISABLEUNPACKWARS" ]; then
      echo -n "  Disable unpackwars? [y/n] "
      read DISABLEUNPACKWARS
    fi
    if [ "$DISABLEUNPACKWARS" = "n" ]; then break; fi
    if [ "$DISABLEUNPACKWARS" != "y" ]; then continue; fi
    echo "  ...disabling the unpackWARs option"
    sed -i 's/unpackWARs="true"/unpackWARs="false"/' conf/server.xml
    break
  done

  while true; do
    if [ -z "$URIUTF8" ]; then
      echo -n "  Change URI encoding from default (ISO-8859) to UTF8?  [y/n] "
      read URIUTF8
    fi
    if [ "$URIUTF8" = "n" ]; then break; fi
    if [ "$URIUTF8" != "y" ]; then continue; fi
    echo "  ...setting URI encoding to utf-8"
    sed -i 's/Connector port=/Connector URIEncoding="UTF-8" port=/' conf/server.xml
    break
  done

  while true; do
    if [ -z "$REMADMIN" ]; then
      echo -n "  Remove the tomcat manager webapps ? [y/n] "
      read REMADMIN
    fi
    if [ "$REMADMIN" = "n" ]; then echo "  ...leaving the manager webapps"; break; fi
    if [ "$REMADMIN" != "y" ]; then continue; fi
    echo "  ...removing the manager webapps"
    if [ -e webapps/host-manager ]; then mv webapps/host-manager webapps/manager webapps.removed/; fi
    break
  done

  while true; do
    # doing this since the default is 1.6.  And that will spit an error if you use @Override, or 
    # do something like new Comparator<Foo> {..} which has new default methods in 1.8 
    if java -version 2>&1 | grep -qai 1.8 > /dev/null; then
      JSPVERSION=1.8
    fi 
    if java -version 2>&1 | grep -qai 1.7 > /dev/null; then
      JSPVERSION=1.7
    fi 
    if [ -z "$JSPVERSION" ]; then break; fi
    if grep -qai 'name>compilerTargetVM' /usr/local/tomcat/conf/web.xml; then break; fi
    sed -i "s|er.servlet.JspServlet</servlet-class>|er.servlet.JspServlet</servlet-class>\
  <init-param><param-name>compilerTargetVM</param-name><param-value>$JSPVERSION</param-value></init-param>\
        <init-param><param-name>compilerSourceVM</param-name><param-value>$JSPVERSION</param-value></init-param>|" /usr/local/tomcat/conf/web.xml
    echo "  ...updated the default web.xml to use Target/Source VM of $JSPVERSION"
    break; 
  done
  # create a logrotate script for tomcat logs
  echo "  ...creating a custom logrotate script for tomcat logs"
  mkdir -p /etc/logrotate.d
  echo "$INSTALLTARGET/logs/catalina.out {
copytruncate
daily
nocreate
size 5M
rotate 7
missingok
sharedscripts
prerotate
  find $INSTALLTARGET/logs/ -mtime +7 -type f | egrep '\.log|\.gz' | xargs -i{} rm -f '{}'
endscript
}
" > /etc/logrotate.d/tomcat

  # set tomcat running on startup if needed/wanted
  while true; do
    if [ -z "$RUNONSTARTUP" ]; then
      echo -n "  Make tomcat run on startup? [y/n] "
      read RUNONSTARTUP
    fi
    if [ "$RUNONSTARTUP" = "n" ]; then break; fi
    if [ "$RUNONSTARTUP" != "y" ]; then continue; fi
    # make tomcat start on startup
    echo "  ...setting tomcat to run on system startup"
    if [ -e /etc/debian_version ]; then
      update-rc.d tomcat defaults
    else
      chkconfig --add tomcat
    fi
    break
  done
}

###
# Function: portapps
# Do final system tweaks to make the install more useable
#
function portapps {
  [[ ! -d "$MVDIRNAME" ]] && return
  if [[ ! -z "$NOMIGRATE" ]]; then
    echo "  ...skipping any migration tasks since you said so"
    return
  fi

  echo "  ...checking in case migration tasks are better done manually"
  if [[ $(grep -c '<Host' $MVDIRNAME/conf/server.xml) -ne 1 ]] ; then
    echo "! WARNING: custom 'host' entries in old server.xml. This script cannot migrate
  over those entries safely. Exiting without porting any content from
  $MVDIRNAME to the upgrade."
    return;
  fi

  echo "  ...checking for custom webapps to migrate into new instance"
  cd "$MVDIRNAME/webapps"
  if [ $? -ne 0 ]; then echo "! WARNING: could not change to the old webapp directory.  Not copying the original webapps." >&2; return 1; fi
  webapplist="(ls $INSTALLTARGET/webapps)"
  # FIXME should we add some interaction below?
  for i in *; do
    # get this if we are in an empty directory
    if [[ "$i" == "*" ]] ; then continue; fi
    if [[ "$i" == "ROOT" && -e "ROOT/tomcat.gif" ]]; then
      continue  # dont copy the ROOT webbapp over since its just the default
    elif [[ $(echo $webapplist | grep -c $i) -ne 0 ]]; then
      continue  # avoid overwriting existing webbapps
    elif [[ $(echo "docs examples manager host-manager test" | grep -c $i) -gt 0 ]]; then
      continue  # dont update default webapps
    fi
    echo "     copy $i to $INSTALLTARGET/webapps"
    rm -rf "$INSTALLTARGET/webapps/$i"
    cp -a "$i" "$INSTALLTARGET/webapps"
  done
}


parsecommandline $*
if [[ $? -ne 0 ]]; then
  echo
  version
  usage
  echo "! Error from postinstall: $ERRORMSG"
  echo
  exit 1
fi
CALLER=$(ps ax | grep "^ *$PPID" | awk '{print $NF}')
[[ -z $NOPROMPT && "$CALLER" == "-bash" ]] && version

installreqs
if [[ $? -ne 0 ]]; then
  echo
  echo "! Error from requirements: $ERRORMSG"
  echo
  exit 1
fi

installtomcat
if [[ $? -ne 0 ]]; then
  echo
  echo "! Error from install: $ERRORMSG"
  echo
  exit 1
fi

portapps
if [[ $? -ne 0 ]]; then
  echo
  echo "! Error from migration: $ERRORMSG"
  echo
  exit 1
fi

echo -n "* Make sure the service is running"
$INITSCRIPT restart  >> /dev/null 2>&1
if [[ $($INITSCRIPT status | grep -c 'PIDs') < 1 ]]; then
  echo ", failed"
  echo "! Error: tomcat not started cleanly, this should not happen. Check your install"
  echo "! manually or consider rerunning with the --skip-migrate-webapps option"
else
  ipaddr="$(ifconfig eth0 | grep "inet addr:" | awk '{print $2}' | cut -d: -f2)"
  echo ", ok"
  echo "* Tomcat is now installed and should be visible on http://$ipaddr:8080"
fi

# EOF
