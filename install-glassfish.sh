#!/bin/bash

#
# $Id: installglassfish.sh 332 2013-08-26 00:16:25Z john $
#

INSTALL_LOC="/usr/local"
INSTALL_LOG="/root/glassfish_install.log"
FILE="glassfish-"
# can use version option to change to version 4
# by default run w/ no args will install this: 
VERSION="3.1.2.2"
# -v 4 will overwrite the above with this version: 
ALTVERSION="4.0"
EXT="zip"
# need this below now dealing w/ 2 versions.
#FILE_SOURCE="http://download.java.net/glassfish/$VERSION/release/"
TIMESTAMP=`date +%H%M%d%m%G`
# set later after we check:
JAVA_VER=
ERRMSG=""
NOPROMPT="N"

###
# Function: echolog
# view std out and append to log
#
function echolog() {
  echo -e $* | tee -a $INSTALL_LOG
}

###
# Function: usage
# helpful message where its needed
#
function usage {
  echo "Usage: $0  [ --version [3] or [4]|--help|--usage|--noprompt]" >&2
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
          --help | --usage)
            usage
            exit 0;
          ;;
          --version | -v)
          shift
          if [[ -z "$1" ]]; then
            echo "Error: $PARAM given without version, use 3 or 4"
            usage
            exit 1
          elif [[ "$1" != "3" && "$1" != "4" ]]; then
            ERRORMSG="$PARAM given with unsupported version '$1', use 3 or 4"
          return 1
          fi
          if [ $1 -eq 4 ]; then 
          # Set versions at the top 
          VERSION="$ALTVERSION"
          fi
          FILE_SOURCE="http://download.java.net/glassfish/$VERSION/release/"
	  # above seems to redirict to: 
          #FILE_SOURCE="http://dlc.sun.com.edgesuite.net/glassfish/$VERSION/release/"
          ;;
          --noprompt)
            NOPROMPT="Y"
          ;;
          *)
            ERRORMSG="unknown parameter found"
            if [[ -n "$1" ]]; then
                ERRORMSG="$ERRORMSG '$1'"
            fi
            return 1
          ;;
        esac
        shift
    done

    if [[ -n $ERRMSG ]]; then
        usage
        echolog "Error: $ERRORMSG" >&2
        echo
        exit 1
    fi
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

  # TODO add java presence install
  [[ -e /etc/profile.d/java.sh ]] && source /etc/profile.d/java.sh
  if [[ ! $(which java 2>/dev/null) ]]; then
    echolog "Notice: No JDK installed, installing JDK 7 for either version"
    wget -q http://downloads.rimuhosting.com/installjava.sh
    bash installjava.sh
    rm -f installjava.sh
  fi

# Since we either installed a JDK or found one, lets set this: 
JAVA_VER=$(java -version 2>&1 | sed 's/java version "\(.*\)\.\(.*\)\..*"/\1\2/; 1q')

# You'll have to change this once 4.x becomes the standard 
  if [[ "$JAVA_VER" -le "16" ]] && [[ $VERSION == $ALTVERSION ]]; then
    echolog "Glasfish 4+ requires JDK 7, looks like you have an older version installed:"
    java -version
    echolog "Try updating that with http://proj.ri.mu/installjava.sh"
    exit 1
  fi

  if [[ "$JAVA_VER" -le "14" ]]; then
    echolog "Glassfish 3+ requires Java SE 6.0 or later. Glassfish 4+ requires Java 7+"
    echolog "Found an older version installed:"
    java -version
    echolog "Try updating that with http://proj.ri.mu/installjava.sh"
    exit 1
  fi

}


##
# Function: installpackage
# take what we know and install our package! :D
#
function installpackage {
    # go to location
    cd $INSTALL_LOC

    # sanity check
    if [ -e $INSTALL_LOC/glassfish ]; then
      if ps aux | grep -q '[j]ava.*glassfish' && [ -e /etc/init.d/glassfish ]; then
	echolog "NOTICE: Found a running instance of glassfish, attemping to shut down with initscript"
	/etc/init.d/glassfish stop
      fi
      if [ "$NOPROMPT" == "Y" ] || [ "$NOPROMPT" == "y" ]; then
        mv $INSTALL_LOC/glassfish $INSTALL_LOC/glassfish.old.$TIMESTAMP
        echolog "NOTICE: moved $INSTALL_LOC/glassfish to $INSTALL_LOC/glassfish.old.$TIMESTAMP"
      else
        echolog "$INSTALL_LOC/glassfish exists, should I move it? [Y/N]"
        read moveglassfish
        if [ "$moveglassfish" == "Y" ] || [ "$moveglassfish" == "y" ]; then
          mv $INSTALL_LOC/glassfish $INSTALL_LOC/glassfish.old.$TIMESTAMP
          echolog "NOTICE: moved $INSTALL_LOC/glassfish to $INSTALL_LOC/glassfish.old.$TIMESTAMP"
        else
          exit 0
        fi
      fi
    fi
    
    # get glassfish 
    if [ -e $FILE ]; then
        echolog "NOTICE: Skipping the glassfish download"
    else
        echolog "NOTICE: Getting $FILE_SOURCE/$FILE"
        wget "$FILE_SOURCE/$FILE" -O $FILE -a $INSTALL_LOG
        if [ $? -ne 0 ] ; then
            echolog "ERROR: Failed getting $FILE_SOURCE/$FILE"
            return 1
        fi
    fi

    # unpack...
    if [[ $EXT == "jar" ]]; then
       echolog "NOTICE: Unacking $FILE"
       java -Xmx256m -jar $FILE  >> $INSTALL_LOG 2>&1
    elif [[ $EXT == "tar.gz" ]]; then
       echolog "NOTICE: Unacking $FILE"
       tar -xzf $FILE  >> $INSTALL_LOG 2>&1
    elif [[ $EXT == "tar.bz2" ]]; then
       echolog "NOTICE: Unacking $FILE"
       tar -xjf $FILE  >> $INSTALL_LOG 2>&1
    elif [[ $EXT == "zip" ]]; then
       echolog "NOTICE: Unacking $FILE"
       unzip $FILE  >> $INSTALL_LOG 2>&1
    else
        echolog "NOTICE: Unrecognised package format, giving up"
        exit 1;
    fi

    if [ -e $INSTALL_LOC/glassfish ]; then
      mv $INSTALL_LOC/glassfish $INSTALL_LOC/glassfish.old.$TIMESTAMP
    fi
    # mv unpacked directory for whichever version: 
    mv $INSTALL_LOC/glassfish3 $INSTALL_LOC/glassfish
    mv $INSTALL_LOC/glassfish4 $INSTALL_LOC/glassfish
	
    # Check if user already exists
    getent passwd glassfish > /dev/null
  if [ $? -eq 0 ]; then
    echolog "NOTICE: glassfish user already exists"
   else
    # add glassfish user
    echolog "NOTICE: Adding glassfish user"
    if [ -e /etc/debian_version ]; then
      adduser --shell /sbin/nologin --home /usr/local/glassfish --system glassfish >> $INSTALL_LOG 2>&1
      addgroup --system glassfish >> $INSTALL_LOG 2>&1
      adduser glassfish glassfish >> $INSTALL_LOG 2>&1
    else
      adduser -s /sbin/nologin -d /usr/local/glassfish glassfish >> $INSTALL_LOG 2>&1
    fi
  fi

    # set ownship of glassfish install location
    echolog "NOTICE: Setting ownership of $INSTALL_LOC/glassfish"
    chown -R glassfish:glassfish $INSTALL_LOC/glassfish >> $INSTALL_LOG 2>&1
    chown -R glassfish:glassfish $INSTALL_LOC/glassfish/* >> $INSTALL_LOG 2>&1
}

###
# Function setuppackage
# runs the setup of glassfish
#
function setuppackage {
    # set java location
    sed -i 's/JAVA=java/JAVA=\/usr\/java\/jdk\/bin\/java/' $INSTALL_LOC/glassfish/bin/asadmin
    # bind glassfish to localhost
    sed -i 's/0.0.0.0/127.0.0.1/' $INSTALL_LOC/glassfish/glassfish/domains/domain1/config/domain.xml
    sed -i '/<network-listener port="8080" protocol="http-listener-1"/<network-listener port="8080" protocol="http-listener-1" address="127.0.0.1"/' $INSTALL_LOC/glassfish/glassfish/domains/domain1/config/domain.xml
    sed -i 's/<network-listener port="8181" protocol="http-listener-2"/<network-listener port="8181" protocol="http-listener-2" address="127.0.0.1"/' $INSTALL_LOC/glassfish/glassfish/domains/domain1/config/domain.xml
    sed -i 's/<network-listener port="4848" protocol="admin-listener"/<network-listener port="4848" protocol="admin-listener" address="127.0.0.1"/' $INSTALL_LOC/glassfish/glassfish/domains/domain1/config/domain.xml
}

# get set up
parsecommandline $*

# make sure we have unzip for later
apt-get -y install unzip zip >> $INSTALL_LOG 2>&1

# do the install
FILE="$FILE$VERSION.$EXT"
installreqs
installpackage

# do the setup
echolog "NOTICE: Running setup of glassfish"
setuppackage >> $INSTALL_LOG 2>&1

# install init script
echolog "NOTICE: installing glassfish init script"

echo <<INITSCRIPT >/etc/init.d/glassfish '#!/bin/bash

#
# Startup script for Glassfish
#
# chkconfig: 345 94 16
# description: Glassfish
#

GLASSFISHHOME=/usr/local/glassfish
DOMAIN="domain1"

export JAVA_HOME=/usr/java/jdk

case "$1" in
  start)
    su - glassfish -s /bin/sh -c "$GLASSFISHHOME/bin/asadmin start-domain $DOMAIN"
  ;;
  stop)
    su - glassfish -s /bin/sh -c "$GLASSFISHHOME/bin/asadmin stop-domain $DOMAIN"
  ;;
  restart)
    su - glassfish -s /bin/sh -c "$GLASSFISHHOME/bin/asadmin stop-domain $DOMAIN"
    su - glassfish -s /bin/sh -c "$GLASSFISHHOME/bin/asadmin start-domain $DOMAIN"
  ;;
  *)
    echo $"usage: $0 {start|stop|restart}"
    exit 1
esac
'
INITSCRIPT

chmod +x /etc/init.d/glassfish

# start glassfish
echolog "NOTICE: starting glassfish"
/etc/init.d/glassfish start >> $INSTALL_LOG 2>&1

sleep 10
echolog "NOTICE: installing the ajp connector so mod_proxy_ajp can be used"
cd /usr/local/glassfish && ./bin/asadmin create-network-listener  --listenerport 8009 --address 127.0.0.1 --protocol http-listener-1 --jkenabled true jk-connector

# clean up
echolog "NOTICE: cleaning up after installation"
rm $INSTALL_LOC/$FILE

# output user information
echolog "Glassfish is now installed, access the admin console at http://127.0.0.1:4848/"
echolog "Please set an admin password via the admin console by going to"
echolog "\"Enterprise Server\" then \"Administrator Password\"."
