#!/bin/bash -x

##
# $Id: installjava.sh 392 2014-08-10 21:57:23Z root $
# NOTE: this script expects 32/64 bit tar files to have been created from
#       the main package for the --accept-license option to work
# TODO add java docs to the list?
##

# some globals
export DEBIAN_FRONTEND="noninteractive"
WGET_OPTS="--tries=2 --timeout=10 --quiet"
FILE_SOURCE="http://downloads.rimuhosting.com"

# what and where
JRE="7"
INSTALLTARGET="/usr/java"
UNPACKDIR=
FILE=
FILEVER=
ARCH="linux-i586"
EXT="tar.gz"

# some vars
ARCH_WANTED=
NOPROMPT=
ERRORMSG=

###
# Function: version
# Tell us what version the script is... duh :)
#
function version {
  echo "
  $0 ($Id: installjava.sh 392 2014-08-10 21:57:23Z root $)
  Copyright Rimuhosting.com
  Install Oracle Java JDK from Oracle's tar.gz download
"
}

###
# Function: usage
# helpful message where its needed
#
function usage {
  echo " Usage: $0 [--jre [7] or [6] or [8] [--64bit] [--32bit] [--noprompt]

  Option:         Description:
  --64bit         force 64bit install (default matches os)
  --32bit         force 64bit install (default matches os)
  --jre           choose the java version (default is 7, also accept v5 and v6 and v8)
  --noprompt      dont ask any questions, fail gracefully
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
    --64bit)
      ARCH_WANTED=64
      ;;
    --32bit)
      ARCH_WANTED=32
      ;;
    --jre)
      shift
      if [[ "$1" != "5" && "$1" != "6" && "$1" != "7" && "$1" != "8" ]]; then
        ERRORMSG="$PARAM must be followed by the desired jdk version (defaults to 7)"
        return 1
      fi
      JRE="$1"
      ;;
    --noprompt)
      NOPROMPT=n
      ;;
    h|-h|--help|?|-?)
      version
      usage
      exit 0;
      ;;
    *)
      ERRORMSG="unrecognised paramter '$PARAM'"
      return 1
      ;;
    esac
    shift
  done

  if [[ $(id -u) != "0" ]] ; then
    ERRORMSG="you should be root to run this (e.g. sudo $0 $* ) "
    return 1
  fi
  # Install 64bit unless 32bit requested.
  if [[ "${ARCH_WANTED}" == "64" ]]; then
    if [[ "$(uname -a | grep -c x86_64)" -ne "0" ]]; then
      ARCH="linux-x64"
    else
      ERRORMSG="requested a 64bit install, but not on a 64bit OS, giving up"
      return 1
    fi
  elif [[ -z "${ARCH_WANTED}" && "$(uname -m)" == "x86_64" ]]; then
    ARCH="linux-x64"
  # else default is fine
  fi

  # we try to failover the the bin file if a tar.gz is not found, that an install still works. For v6 we 
  # have to make the tar.gz ourselves by installing from the bin then making it from the resulting files.
  if [[ "$JRE" == "8" ]]; then                                                 
     FILEVER=jdk-8u11
     UNPACKDIR=jdk1.8.0_11
  elif [[ "$JRE" == "7" ]]; then
    FILEVER=jdk-7u67
    UNPACKDIR=jdk1.7.0_67
  elif [[ "$JRE" == "6" ]]; then
    FILEVER=jdk-6u45
    UNPACKDIR=jdk1.6.0_45
  elif [[ "$JRE" == "5" ]]; then
    FILEVER=jdk-1_5_0_22
    UNPACKDIR=jdk1.5.0_22
    [[ "$ARCH" == "linux-x64" ]] && ARCH="linux-amd64"
  fi
  if [[ -z "$FILEVER" ]]; then
    ERRORMSG="invalid version. Choose '--jre 5' or '--jre 6' (BUG)"
    return 1
  fi
  }

##
# Function: installpackage
# take what we know and install our package! :D
#
function installjava {
  echo "* Installing Java JDK version $JRE"

  if [[ "$JRE" == "5" ]]; then
    echo "! J2SE 5.0 install requested. Please note J2SE 5.0 reached its official End of Service Life (EOSL) on November 3, 2009"
  fi

  # detect distro and release
  if [ -e /etc/redhat-release ]; then
    DISTRO=( `grep release /etc/redhat-release | awk '{print $1}'` )
    RELEASE=( `grep release /etc/redhat-release | awk '{print $3}' | cut -d. -f1` )
  elif [ -e /etc/debian_version ]; then
    if [[ "$(which lsb_release >> /dev/null 2>&1 && echo $?)" -ne "0" ]]; then
      echo "  ...'lsb_release' command not found, installing as prerequisite"
      apt-get -y -qq install lsb_release  >> /dev/null 2>&1
      if [[ $? -ne 0 ]]; then
        echo -n " ok"
      fi
    fi
    if [[ "$(which lsb_release >> /dev/null 2>&1 && echo $?)" -eq "0" ]]; then
      DISTRO=$(lsb_release -is)
      RELEASE=$(lsb_release -cs)
    fi
  else
    echo "! Running on unknown distro, some features may not work as expected"
  fi
  [[ -z "$DISTRO" ]] && echo "! Warning: Was not able to identify distribution"
  [[ -z "$RELEASE" ]] && echo "! Warning: Was not able to identify release"

  # chuck it all in a big list, these libs nice but not critical afaik
  # and they will date rapidly
  if [[ "$(uname -m)" == "x86_64" && "$ARCH_WANTED" == "32" ]]; then
    echo -n "  ...installing compatiblity libraries:"
    for i in ia32-libs compat-libstdc++-33 compat-libstdc++-296 glibc.i686; do
      apt-get -y -qq install $i  >> /dev/null 2>&1
      if [[ $? -eq 0 ]]; then
        echo -n " $i"
      fi
    done
    echo
  fi

  # go to location
  mkdir -p "$INSTALLTARGET"
  cd "$INSTALLTARGET"

  # sanity check and get binary, failover if no one bothered to build
  # the archives and we only have a source .bin on downloads
  FILE="jdk/$FILEVER-$ARCH.$EXT"
  if [ ! -e $FILE ]; then
    echo "  ...getting source archive"
    wget $WGET_OPTS "$FILE_SOURCE/$FILE"
    if [ ! -e "$FILE" ] ; then
       EXT="tar.gz"
       FILE="$FILEVER-$ARCH.$EXT"
       wget $WGET_OPTS "$FILE_SOURCE/$FILE"
    fi
    if [ ! -e "$FILE" ] ; then
       EXT="bin"
       FILE="$FILEVER-$ARCH.$EXT"
       wget $WGET_OPTS "$FILE_SOURCE/$FILE"
    fi
    if [ ! -e "$FILE" ] ; then
      ERRORMSG="failed getting source $FILE_SOURCE/$FILE"
      return 1
    fi
  fi

  # unpack...
  echo "  ...uncompressing archive, please be patient"
  if [[ $EXT == "tar.bz2" ]]; then
    tar -xjf $FILE
  elif [[ $EXT == "tar.gz" ]]; then
    tar -xzf $FILE
  elif [[ $EXT == "bin" ]]; then
    chmod +x $FILE && ./$FILE
  else
    ERRORMSG="unrecognised package format, giving up"
    return 1;
  fi

  # clean up
  echo "  ...moving files to the right place"
  rm -f "$INSTALLTARGET/jdk"
  ln -sf "$INSTALLTARGET/$UNPACKDIR" "$INSTALLTARGET/jdk"
  if [ $? -ne 0 ] ; then
    echo "failed creating a $INSTALLTARGET/jdk symlink" >&2
    return 1
  fi
}

##
# Function: setupjavaenv
# set JAVA_HOME and other helpful things. default to profile.d location first
#
function setupjavaenv {
  if [ -d /etc/profile.d ]; then
    echo '#!/bin/bash' > /etc/profile.d/java.sh
    echo "export JAVA_HOME=$INSTALLTARGET/jdk
export PATH=$INSTALLTARGET/jdk/bin:\$PATH" >> /etc/profile.d/java.sh
    chmod +x /etc/profile.d/java.sh
    #For when tomcat needs to be installed immediately after:
    source /etc/profile.d/java.sh
    echo "  ...added JAVA_HOME in /etc/profile.d/java.sh"
  elif [ -e /etc/profile ]; then
    grep -qai JAVA_HOME /etc/profile
    if [ $? -ne 0 ]; then
      echo "export JAVA_HOME=$INSTALLTARGET/jdk
export PATH=$INSTALLTARGET/jdk/bin:\$PATH" >> /etc/profile
      echo "  ...added java_home in /etc/profile"
    else
      echo "  ..JAVA_HOME already set in /etc/profile.  check it is OK?"
      grep -i java /etc/profile
    fi
  else
    ERRORMSG="no /etc/profile[.d], setup java home/path manually"
    return 1
  fi

  # get rid of the kaffe/faux java symlink
  find /usr/bin -type l -name java | xargs rm -f
}


# get set up
parsecommandline $*
if [[ $? -ne 0 ]]; then
  version
  usage
  echo "! Error on commandline: $ERRORMSG"
  echo
  exit 1
fi
CALLER=$(ps ax | grep "^ *$PPID" | awk '{print $NF}')
[[ -z $NOPROMPT && "$CALLER" == "-bash" ]] && version

# do the install
installjava
if [[ $? -ne 0 ]]; then
  echo
  echo "! Error on install: $ERRORMSG"
  echo
  exit 1
fi

setupjavaenv
if [[ $? -ne 0 ]]; then
  echo
  echo "! Error in env setup: $ERRORMSG"
  echo
  exit 1
fi

# clean up
rm $INSTALLTARGET/$FILE


