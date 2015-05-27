#!/bin/bash

# Copyright Rimuhosting.com
# 
# TODO
# better init script, that supports pid files and status
# target for installation. remove any trailing /s
# logrotate

DEFAULTINSTALLTARGET="/usr/local/jboss"
INSTALLTARGET=
INITSCRIPT="/etc/init.d/jboss"
JBOSSURL="http://download.jboss.org/jbossas/7.1/jboss-as-7.1.1.Final/jboss-as-7.1.1.Final.tar.gz"
MYSQLCONNECTORURL="http://d.ri.mu/mysql-connector-java-5.1.18-bin.jar"

# default values
ERRORMSG=
MVDIRSTAMP="old.$(date +%s)"
MVDIRNAME=
NOPROMPT=
NOJAVA="n"
RUNONSTARTUP="n"
MYSQLCONNECTOR="n"




###
# Function: usage
# Handy function to tell users whats what
# TODO: add boilerplate?
#
function usage {
  echo " Usage: $0 [--noprompt]
      [--installtarget <folder>] [--skip-java]
      [--mysqlconnector]
      [--runonstartup]

  Option notes:
  --noprompt      makes safe assumptions and runs without user interaction
  --installtarget optional install location (default is $DEFAULTINSTALLTARGET)

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
      ;;
    --runonstartup)
      RUNONSTARTUP="y"
      ;;
    --skip-java)
      NOJAVA="y"
      ;;
    --mysqlconnector)
      MYSQLCONNECTOR="y"
      ;;
    -h|help|-help|--help|?|-?|--?)
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
  
  return 0

}


###
# Function: installreqs
# Make sure any essential components need for this script or the jboss install are available
#
function installreqs {
  echo "* Verifying installation requirements"
  if [[ $(id -u) != "0" ]] ; then
    ERRORMSG="You should be root to run this (e.g. sudo $0 $* ) "
    return 1
  fi

  echo "  ...checking for existing jboss installations"
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
    if [ "$NOJAVA" = "y" ]; then
      ERRORMSG="java not found in the system path, install that before proceeding?"
      return 1
    fi
    wget -q http://downloads.rimuhosting.com/installjava.sh
    bash installjava.sh
    rm -f installjava.sh
  fi

}



###
# Function: installjboss
# Actually do the jboss package install
#
function installjboss {
  echo "* Installing JBoss"

  # remove existing (old or conflicting) init scripts to backup location
  MVDIRNAME="$INSTALLTARGET.$MVDIRSTAMP"
  jbossscripts=`find /etc/init.d/ | xargs grep -c $INSTALLTARGET | grep -v ":0$" | cut -d: -f1`
  if [ ! -z "$jbossscripts" ]; then
    for i in $jbossscripts; do
      echo "  ...attempting to stop existing jboss instance managed by $i to avoid conflicts"
      $i stop  >> /dev/null 2>&1
      sleep 1
      if [[ $($i status | grep -c 'PIDs') > 0 ]]; then
        ERRORMSG="jboss not stopped cleanly, this should not happen (BUG)"
        return 1
      fi
    done
      if [ "$(ps aux | grep -c "^jboss")" -ne "0" ]; then
	ERRORMSG="user jboss still has processes running"
	return 1
      fi
    for i in $jbossscripts; do
      echo "  ...init script $i moved to $(dirname $INSTALLTARGET)/$(basename $i).$MVDIRSTAMP.init"
      mv $i "$(dirname $INSTALLTARGET)/$(basename $i).$MVDIRSTAMP.init"
    done
  fi

  # move old jboss installs out of the way with a datestamp
  if [ -e $INSTALLTARGET ]; then
    echo "  ...found $INSTALLTARGET, backing up directory to $MVDIRNAME"
    mv "$INSTALLTARGET" "$MVDIRNAME"
  fi

  #####NEW INIT SCRIPT	
  echo <<INITSCRIPTEOF >$INITSCRIPT '
#!/bin/sh
### BEGIN INIT INFO
# Provides: jboss
# Required-Start: $local_fs $remote_fs $network $syslog
# Required-Stop: $local_fs $remote_fs $network $syslog
# Default-Start: 2 3 4 5
# Default-Stop: 0 1 6
# Short-Description: Start/Stop JBoss AS v7.0.0
### END INIT INFO
#


JBOSS_HOME=/usr/local/jboss

JAVA_HOME=/usr/java/jdk

export JAVA_HOME
export JBOSS_HOME


EXEC=${JBOSS_HOME}/bin/standalone.sh

if [ -e /etc/redhat-release ]; then
	. /etc/init.d/functions
fi


do_start(){
	if [ -e /etc/redhat-release ]; then
		daemon --user jboss ${EXEC} > /dev/null 2> /dev/null &
	else
		start-stop-daemon --start --chuid jboss --user jboss --name jboss -b --exec ${EXEC}
	fi
}

do_stop(){
	if [ -e /etc/redhat-release ]; then
		killall -u jboss
	else
		start-stop-daemon --stop -u jboss
	fi
	rm -f ${PIDFILE}
}

case "$1" in
    start)
        echo "Starting JBoss AS"
	do_start
    ;;
    stop)
        echo "Stopping JBoss AS"
	do_stop
    ;;
    restart)
	echo "Restarting JBoss AS"
	do_stop
	sleep 10
	do_start
    ;;
    *)
        echo "Usage: /etc/init.d/jboss {start|stop|restart}"
        exit 1
    ;;
esac

exit 0
'
INITSCRIPTEOF

  chmod +x $INITSCRIPT

  # make sure the init script is pointing at the right place
  if [[ "$INSTALLTARGET" != "$DEFAULTINSTALLTARGET" ]]; then
    sed -i "s/JBOSS_HOME=$DEFAULTINSTALLTARGET/JBOSS_HOME=$INSTALLTARGET/" $INITSCRIPT
  fi

  echo "  ...installing JBoss package to $INSTALLTARGET"
  installtop=$(dirname $INSTALLTARGET)
  cd $installtop
  wget --quiet -O - "$JBOSSURL" | tar xz
  if [ $? -ne 0 ]; then ERRORMSG="failed downloading or uncompressing jboss package"; return 1; fi
  mv "$installtop"/jboss-as-7* "$INSTALLTARGET"

 echo

  # create jboss user and group if they do not exist
  if [[ $(id jboss 2>&1 | grep -c "No such user") -gt "0" ]]; then
    echo "  ...configuring service user and group"
    if [[ $DISTRO == "Debian" || $DISTRO == "Ubuntu" ]]; then
      adduser --system --group jboss --home $INSTALLTARGET >> /dev/null 2>&1
    elif [[ $DISTRO == "CentOS" || $DISTRO == "RHEL" || $DISTRO == "Fedora" ]]; then
      groupadd -r -f jboss  >> /dev/null 2>&1
      useradd -r -s /sbin/nologin -d $INSTALLTARGET -g jboss jboss >> /dev/null 2>&1
    else
      echo "Warning: Distribution not recognised, you may need to configure the"
      echo "         jboss user and group manually. Attempting to perform this"
      echo "         anyway"
      groupadd jboss  >> /dev/null 2>&1
      useradd -s /sbin/nologin -d $INSTALLTARGET -g jboss jboss >> /dev/null 2>&1
    fi
  fi
  if [[ $(id jboss 2>&1 | grep -c "No such user") -gt 0 ]]; then
    ERRORMSG="failed adding jboss user, bailing. Check your system?"
    return 1
  fi

  chown -R jboss:jboss $INSTALLTARGET

  # override default memory settings


  # logs config

  # set jboss running on startup if needed/wanted

    if [ -z "$NOPROMPT" ] && [ $RUNONSTARTUP = "n"  ]; then
      echo -n "  Make jboss run on startup? [y/n] "
      read RUNONSTARTUP
      while echo $RUNONSTARTUP | grep -qv '^y$\|^n$' ; do
	echo -n "  Make jboss run on startup? [y/n] "
        read RUNONSTARTUP
      done
    fi
    
    if [ "$RUNONSTARTUP" = "y" ]; then
      # make jboss start on startup
      echo "  ...setting jboss to run on system startup"
    	if [ -e /etc/debian_version ]; then
	  update-rc.d jboss defaults
        else
          chkconfig --add jboss
        fi
    fi
    # disable jmx remote access
    echo "  ...securing JBoss, disabling JMX remote access"
    sed -i 's|\(<remoting-connector/>\)|<!-- \1 -->|g' $INSTALLTARGET/standalone/configuration/standalone.xml 
}


function installmysqlconnector {
    echo "  ...installing the mysql connector"
    local MYSQLCONNECTORTARGETDIR="$INSTALLTARGET/modules/com/mysql/main"
    mkdir -p $MYSQLCONNECTORTARGETDIR
    cd $MYSQLCONNECTORTARGETDIR
    wget --quiet $MYSQLCONNECTORURL
    echo <<EOFMODULE >$MYSQLCONNECTORTARGETDIR/module.xml '
<?xml version="1.0" encoding="UTF-8"?>
 
<module xmlns="urn:jboss:module:1.0" name="com.mysql">
  <resources>
    <resource-root path="mysql-connector-java-5.1.17-bin.jar"/>
  </resources>
  <dependencies>
    <module name="javax.api"/>
  </dependencies>
</module>
'
EOFMODULE

    sed -i 's/mysql-connector-java.*-bin\.jar/'$(basename $(echo $MYSQLCONNECTORURL | sed 's|^http:/||g'))'/g' $MYSQLCONNECTORTARGETDIR/module.xml

    echo "  ...adding the mysql connector driver to the jboss configuration"
    sed -i 's|\(<drivers>\)|\1\n\t\t<driver name="mysql" module="com.mysql"/>|g' $INSTALLTARGET/standalone/configuration/standalone.xml

    echo ""
    echo "   To add a datasource to an specific database (in uppercase what needs tunning),"
    echo "   you can add the following in the datasources element at the configuration file:"
    echo "   $INSTALLTARGET/standalone/configuration/standalone.xml"
    echo <<EOFDATASOURCEHELP '
<datasource
        jndi-name="java:/DATABASE" pool-name="my_pool"
        enabled="true" jta="true"
        use-java-context="true" use-ccm="true">
    <connection-url>
        jdbc:mysql://localhost:3306/DATABASE
    </connection-url>
    <driver>
        mysql
    </driver>
    <security>
        <user-name>
            DATABASE_USER
        </user-name>
        <password>
 	    DATABASE_PASSWORD
        </password>
    </security>
    <statement>
        <prepared-statement-cache-size>
            100
        </prepared-statement-cache-size>
        <share-prepared-statements/>
    </statement>
</datasource>
'
EOFDATASOURCEHELP
   
    #adjust the permisions once more just in case
    chown -R jboss: $INSTALLTARGET
    return 0
}

parsecommandline $*
if [[ $? -ne 0 ]]; then
  echo
  usage
  echo "! Error from postinstall: $ERRORMSG"
  echo
  exit 1
fi

installreqs
if [[ $? -ne 0 ]]; then
  echo
  echo "! Error from requirements: $ERRORMSG"
  echo
  exit 1
fi

installjboss
if [[ $? -ne 0 ]]; then
  echo
  echo "! Error from install: $ERRORMSG"
  echo
  exit 1
fi

if [ -z "$NOPROMPT" ] && [ $MYSQLCONNECTOR = "n" ]; then
  echo -n "  Install the mysql connector? [y/n] "
    read MYSQLCONNECTOR
      while echo $MYSQLCONNECTOR | grep -qv '^y$\|^n$' ; do
	echo -n "  Install the mysql connector? [y/n] "
        read MYSQLCONNECTOR
      done
fi
    
if [ "$MYSQLCONNECTOR" = "y" ]; then
installmysqlconnector
fi
 


echo -n "* Make sure the service is running"
$INITSCRIPT restart >> /dev/null 2>&1
sleep 5
if [ "$(ps aux | grep -c "^jboss")" -eq "0" ] ; then
  echo "failed"
  echo "! Error: jboss not started cleanly, this should not happen. Check your install"
else
  echo "ok"
  echo "* JBoss is now installed and should be visible on http://127.0.0.1:8080"
  echo 
  echo "You may want to disable the management interfaces, for more information:"
  echo "https://docs.jboss.org/author/display/AS71/Securing+the+Management+Interfaces"
fi

# EOF
