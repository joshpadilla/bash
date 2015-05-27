#!/bin/bash
#
# Install a consistent ruby and rails stack with some handy gems
# Open a ticket/email us if you think this needs to be updated
#

# This script will setup a RAILS stack with the following versions.
# Check the referenced links for the latest versions:
DEFAULT_RUBY_VERSION="1.9.3-p448" # http://www.ruby-lang.org/en/downloads/
ALT_RUBY_VERSION="2.0.0-p247"   # http://www.ruby-lang.org/en/downloads/
RUBY_GEM_VERSION="2.0.7"        # http://rubygems.org/pages/download
GEM_PATH_VERSION="1.9.1"	# used in gem library paths (see the passenger config)
IMAGEMAGIC_VERSION="6.7.9-10"    # http://www.imagemagick.org/script/download.php
# we tend to hang back on image magick versions: http://www.imagemagick.org/download/legacy/
# sometimes new dependencies cause problems, and require a bit of work to figure out
# Use the -j flag to try to find a (slightly older) package and let the distro keep that patched  

# test app installation defaults
RAILS_APP_DEPLOYMENT_DIR="/var/www/apps"
RAILS_TEST_APP="testapp"

export LANG=C

#
####### Some ideas:
# TODO: might want to add node.js install in the future for js engine: 
# https://github.com/sstephenson/execjs#readme
# node.js is a bit of pain to install right now (check: https://github.com/creationix/nvm)
# therubyracer is set in this script, just a gem install and uncomment one line in Rails config
# TODO: setup a "deploy" linux user account. Setup RVM environment there. 
# TODO: -u try to update Ruby branch/Gems option 
# TODO: -n option for nginx setup

# If your updating the versions rember to also update them on downloads:
FILESOURCE="http://downloads.rimuhosting.com" 
# If you want to customize this script w/ your own versions feel free to set your own filesource
# Older releases are occasionally purged from our downloads server, so don't expect them all to be there

# Uninitialized variables use option flags to set non-null 
NOAPT=
BFLAG=
USEREE=
NORDOC=
DEBUG=
NOMAGICK=
PACKMAGICK=
NOGEMINST=
NOMODPASSENGER=
OLDRUBY=

###
# Function: version
#
function version {
echo <<VERSION "
 $Id: rails.sh 343 2013-09-26 06:52:27Z glenn $null
 Copyright Rimuhosting.com - Absolutely no warranty
 feedback: https://rimuhosting.com/support/feedback.jsp
"
VERSION
}

###
# Function: usage
#
function usage {
		echo <<USAGE "
Usage: $(basename $0) [OPTION...]

This script will install a static system wide Ruby stack for your VPS w/ 
some common gems and other dependencies.  If you anticipate requiring multiple
versions of Ruby, or familiar w/ the various options using RVM, you might prefer
using that script instead: 

https://rvm.io/

That Ruby setup script has a lot of options for more complex setups. If you simply 
need one production version of Ruby and just want to update that from time to time 
this script is a good alternative to RVM.  

Run with no options to install default setup with official Ruby 1.9.3 interpreter.

Options: 
 -a	Skip apt-get update && upgrade, and the prerequisite package installation.
 -b	Install recent 2.0.x version of the official Ruby interpreter. alt branch. 
 -d	Run script with debug logging
 -e	Install Ruby Enterprise Edition (REE) (end of life)
 -g	Skip installing common gems
 -h	This help message
 -i	Skip ImageMagick installation
 -j 	use a (slightly older) package version of ImageMagick rather than source install
 -o	Install old 1.8.7 version of the offical Ruby interpreter (end of life)
 -p	Skip mod-passenger/Apache setup
 -r	Skip installing rdoc files 
 -v	Version message
"
USAGE
}

while getopts 'abdeghijoprv' OPTION
do 
		case $OPTION in
				a) NOAPT=1
						;;
				b) BFLAG=1
						;;
				d) DEBUG=1
						;;
		        e) USEREE=1
						;;
			    g) NOGEMINST=1
						;;
				h) usage
				   exit 0;;
				i) NOMAGICK=1
						;;
				j) PACKMAGICK=1
						;;
				r) NORDOC=1
						;;
				o) OLDRUBY=1
						;;
				p) NOMODPASSENGER=1
						;;
				v) version 
				   exit 0;;
				?) echo "Not a valid option."
						usage
						exit 1
						;;
		esac
done
shift $(($OPTIND - 1))

# Check for some conflicting options: 
if [[ "$OLDRUBY" == 1 && "$BFLAG" == 1 ]]; then
 echo "this script not meant to install two versions of Ruby at the same time."     
 echo " * Hint: You can do this if you wanted to though. Suggest you use RVM. "
    exit 1
fi

# Default option: 
if [[ -z "$OLDRUBY" && -z "$BFLAG" && -z "$USEREE" ]]; then
RUBY_VERSION="$DEFAULT_RUBY_VERSION"
echo "Installing default Ruby version: $RUBY_VERSION"
fi

# Alternative branch (2.0.x currently, someday may switch to default)
if [ "$BFLAG" ]; then
  if [ "$USEREE" ]; then
    echo " * Error: This script is not meant to install REE and the official Ruby at the same time"
    echo " * Hint: You can do this if you wanted to though. Suggest you use RVM. "
    exit 1
  fi
  # Set RUBY 2.0.x version here and make sure it's available on downloads
  RUBY_VERSION="$ALT_RUBY_VERSION"
  GEM_PATH_VERSION="2.0.0"
  echo "Installing Ruby version: $RUBY_VERSION"
fi

# Still offer obsolete branches for legacy apps
if [ "$OLDRUBY" ]; then  
  if [ "$USEREE" ]; then
    echo " * Error: This script is not meant to install REE and the official Ruby at the same time"
    echo " * Hint: You can do this if you wanted to though. Suggest you use RVM. "
    exit 1
  fi
  # Set RUBY 1.8.7.x version here and make sure it's available on downloads
  RUBY_VERSION="1.8.7-p370"
  GEM_PATH_VERSION="1.8"
  echo "Installing Ruby version: $RUBY_VERSION"
  echo " * FYI: This version of Ruby is obsolete"
fi

if [ "$USEREE" ]; then
  # Set REE version here and make sure it's available on downloads
  unset $RUBY_VERSION
  REE_VERSION="1.8.7-2012.02"
  GEM_PATH_VERSION="1.8"
  echo "Installing REE version: $REE_VERSION"
  echo " * FYI: This version of Ruby is obsolete"
fi

# Option to not install rodoc files, these are handy on dev servers
# but a waste of space on a production server, and take longer to install
GEMMODG=
if [ "$NORDOC" ]; then 
  GEMMOD="--no-ri --no-rdoc"
fi

# debug so we can make the script less noisy, but still see what happened if needed
[ ! -z "$DEBUG" ] && echo -e "! Debugging mode active, logging extra output to $DEBUG_LOG_FILE\n"
  export DEBUG_LOG_FILE="/dev/null"
if [[ ! -z "$DEBUG" ]]; then
  export DEBUG_LOG_FILE="/root/debug-rails.log"
  echo > "$DEBUG_LOG_FILE"
fi

#detect distro version
if [ -e /etc/redhat-release ]; then
  DISTRO="redhat"
elif [ -e /etc/debian_version ]; then
  DISTRO="debian"
fi

# YUM OR APT, used to use apt on centos but seems to have problems with EPEL packages.  
if [ $DISTRO == "redhat" ]; then
  PKGMNGR="yum -y "
elif [ $DISTRO == "debian" ]; then
  PKGMNGR="apt-get -y --force-yes "
fi

if [ $DISTRO == "redhat" ]; then
  RAILS_APP_CONFIG="/etc/httpd/conf.d/railsapps.conf"
  MOD_RAILS_CONFIG="/etc/httpd/conf.d/mod_rails.conf"
elif [ $DISTRO == "debian" ]; then
  RAILS_APP_CONFIG="/etc/apache2/conf.d/railsapps.conf"
  MOD_RAILS_CONFIG="/etc/apache2/conf.d/mod_rails.conf"
fi

# used for detection of caller (ie login shell or another script)
CALLER=$(ps ax | grep "^ *$PPID" | awk '{print $NF}')

####################
# HELPER FUNCTIONS #
####################

##
# view std out and append to log
function echolog {
  echo "$*" | tee -a "$DEBUG_LOG_FILE"
}

##
# download files etc
function download {
  [ -z "$1" ] && return 1 || local name="$1"
  [ -z "$1" ] && return 1 || local version="$2"
  shift; shift
  [ -z "$*" ] && return 1 || local url="$*"
  mkdir -p /usr/local/src
  cd /usr/local/src
  if [ -d /usr/local/src/$name-$version ]; then
    echolog "  ...source for $name already present, skipping the download"
    cd /usr/local/src/$name-$version
    return 0
  fi
  echolog "  ...grabbing source for $name from $url"
  wget -qO - $url | tar xz
  if [ $? -ne 0 ]; then
    echolog "! Error: failed getting $url"
    return 1
  fi
  cd /usr/local/src/$name-$version
  return 0
}

##
# apt-get update
function aptgetupdate {
  echolog "* Performing system update via package manager"
if [ $DISTRO == "debian" ]; then
  apt-get update >> "$DEBUG_LOG_FILE" 2>&1
fi
  $PKGMNGR upgrade >> "$DEBUG_LOG_FILE" 2>&1
  return 0
}

##
# install prerequisites
function installprereqpackages {
  echolog "* Installing prerequisite packages via package manager"
  if [ $DISTRO == "redhat" ] ; then
    packagelist="make zlib-devel mysql-devel libmysqlclient15-dev readline-devel readline libpng-devel libpng pcre pcre-devel httpd-devel which libtiff-devel libtiff curl-devel curl libcurl-devel libwmf-devel libwmf gd-devel gd libjpeg-devel libjpeg sqlite-devel sqlite freetype-devel openssl-devel gcc-c++ libyaml libyaml-devel"
  elif [ $DISTRO == "debian" ]; then
    packagelist="build-essential zlib1g-dev g++-3.4 libmysqlclient14-dev libreadline5-dev libwmf-bin libmysqlclient15-dev libssl-dev apache2-prefork-dev libfreetype6 libfreetype6-dev libpng12-dev libtiff4 libtiff4-dev libttf2 libcurl4-openssl-dev libyaml-dev zip unzip libreadline-dev libedit-dev libmagickcore-dev libmagickwand-dev"
  fi
  for package in $packagelist; do
    $PKGMNGR install "$package" >> "$DEBUG_LOG_FILE" 2>&1
    [ $? -eq 0 ] && echo "     $package"
  done
  return 0
}

##
# install ImageMagik
function installimagemagik {
  echolog "* Installing ImageMagick v${IMAGEMAGIC_VERSION}"
  download ImageMagick ${IMAGEMAGIC_VERSION} "${FILESOURCE}/rails/ImageMagick-${IMAGEMAGIC_VERSION}.tar.gz"
  if [ $? -ne 0 ]; then echolog "! Error: failed downloading imagemagick"; return 1; fi
  echolog "  ...building from source package, please be patient"
  echo -n "     configure" && `./configure  >> "$DEBUG_LOG_FILE" 2>&1` && \
  echo -n ", make" && `make  >> "$DEBUG_LOG_FILE" 2>&1` && \
  echo -n ", install" && `make install >> "$DEBUG_LOG_FILE" 2>&1` && \
  echo ", done"
  if [ $? -ne 0 ]; then echolog "! Error: ImageMagick make install failed"; return 1; fi
  # Not sure if this is requried, probably won't hurt:
  ldconfig /usr/local/lib
  if [ $DISTRO == "redhat" ] ; then
  export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig"
  ln -s /usr/local/include/ImageMagick/wand /usr/local/include/wand
  ln -s /usr/local/include/ImageMagick/magick /usr/local/include/magick
  fi
}

##
# install ruby-enterprise edition from http://www.rubyenterpriseedition.com/
function installree {
  echolog "* Installing Ruby Enterprise v$REE_VERSION"
  download ruby-enterprise $REE_VERSION "${FILESOURCE}/rails/ruby-enterprise-$REE_VERSION.tar.gz"

  echolog "  ...building from source package, please be patient"
  ./installer --auto=/usr/local >> "$DEBUG_LOG_FILE" 2>&1

  echolog "  ...add link for ruby binary so there'll be a /usr/bin/ruby"
  if [ -e /opt/ruby-enterprise-$REE_VERSION/bin/ -a ! -e /usr/bin/ruby ]; then
    ln -sf /opt/ruby-enterprise-$REE_VERSION/bin/ruby /usr/bin/ruby
  fi
}

##
# install ruby & dev libraries
function installruby {
  echolog "* Installing Ruby v$RUBY_VERSION"
  download ruby $RUBY_VERSION "${FILESOURCE}/rails/ruby-$RUBY_VERSION.tar.gz"
  if [ $? -ne 0 ]; then echolog "! Error: failed downloading ruby"; return 1; fi

  echolog "  ...building from source package, please be patient"
  echo -n "     configure" && `./configure >> "$DEBUG_LOG_FILE" 2>&1` && \
  echo -n ", make" && `make  >> "$DEBUG_LOG_FILE" 2>&1` && \
  echo -n ", test" && `make test  >> "$DEBUG_LOG_FILE" 2>&1` && \
  echo -n ", install" && `make install >> "$DEBUG_LOG_FILE" 2>&1` && \
  echo ", done"
  if [ $? -ne 0 ]; then echolog "! Error: Ruby build failed"; return 1; fi

  echolog "  ...add link for ruby binary so there'll be a /usr/bin/ruby"
  if [ -e /usr/local/bin/ruby -a ! -e /usr/bin/ruby ]; then
    ln -sf /usr/local/bin/ruby /usr/bin/ruby
  fi

  echolog "  ...building readline against newly installed ruby"
  # doing this voodoo to prevent errors like:
  # /usr/local/lib/ruby/1.8/irb/completion.rb:10:in `require’: no such file to load—readline (LoadError)
  cd /usr/local/src/ruby-$RUBY_VERSION/ext/readline
  if [ $? -ne 0 ]; then echolog "! Error: no /usr/local/src/ruby-$VERSION_ACTUAL/ext/readline dir"; return 1; fi
  echo -n "     conf" && ruby extconf.rb >> "$DEBUG_LOG_FILE" 2>&1
  if [ $? -ne 0 ]; then echo; echolog "! Error: readline extconf.rb failed"; return 1; fi
  echo -n ", make" && `make clean  >> "$DEBUG_LOG_FILE" 2>&1` && \
  echo -n ", install" && `make install >> "$DEBUG_LOG_FILE" 2>&1` && \
  echo ", done"
  if [ $? -ne 0 ]; then echolog "! Error: readline build failed"; return 1; fi
  return 0
}

##
# install ruby gem
function installrubygems {
  echolog "* Installing Ruby Gems v$RUBY_GEM_VERSION"
  download rubygems $RUBY_GEM_VERSION ${FILESOURCE}/rails/rubygems-$RUBY_GEM_VERSION.tgz
  if [ $? -ne 0 ]; then echolog "! Error: failed downloading rubygems"; return 1; fi
  echolog "  ...running setup for rubygems"
  ruby setup.rb >> "$DEBUG_LOG_FILE" 2>&1
  if [ $? -ne 0 ]; then echolog "! Error: Rubygems install failed"; return 1; fi
  return 0
}

##
# install commonly used gems
function installcommongems() {
  echolog "* Installing commonly used Ruby Gems"

  # Making an option for w/ or w/out rdoc
  if [ -n "$NORDOC" ]; then
    echo "* Not installing Rdoc files"
  else 
    echolog "  ...force reinstalling rdoc to make later gem builds sane (eg rails)"
    # ref http://railsforum.com/viewtopic.php?id=41111
    gem install rdoc-data >> "$DEBUG_LOG_FILE" 2>&1
    rdoc-data --install >> "$DEBUG_LOG_FILE" 2>&1
    gem rdoc --all --overwrite >> "$DEBUG_LOG_FILE" 2>&1
  fi

  echolog "  ...installing assorted handy gems"
  GEM_LIST="rails capistrano rmagick sqlite3 psych therubyracer"
  for gem in $GEM_LIST; do
    # gem 2.0 removes the "--include-dependencies" option.  
    #gem install $GEMMOD --include-dependencies $gem >> "$DEBUG_LOG_FILE" 2>&1
    gem install $GEMMOD $gem >> "$DEBUG_LOG_FILE" 2>&1
    [ $? -ne 0 ] && echolog "! Error: failed to install gem '$gem'" || echolog "     $gem"
  done

  echolog "  ...do mysql gem last to improve sanity of build"
  if [ $DISTRO == "redhat" ]; then
    gem install $GEMMOD mysql -- --with-mysql-config=/usr/bin/mysql_config >> "$DEBUG_LOG_FILE" 2>&1
  elif [ $DISTRO == "debian" ]; then
    gem install mysql >> "$DEBUG_LOG_FILE" 2>&1
  fi

  echolog "  ...install mod_rails (passenger)"
#  gave up on trying to track mod_rails version
#  gem install $GEMMOD passenger --include-dependencies -v "$MOD_RAILS_VERSION"  >> "$DEBUG_LOG_FILE" 2>&1
  gem install $GEMMOD passenger >> "$DEBUG_LOG_FILE" 2>&1

# Still need the version number though, try this: 
MOD_RAILS_VERSION=$(passenger --version | head -n -1 | sed 's/[[:alpha:]|(|[:space:]]//g' | awk -F- '{print $1}')

  echolog "  ...compile mod_rails apache module"
  passenger-install-apache2-module -a >> $DEBUG_LOG_FILE 2>&1
  return 0
}

##
# Install passenger w/ a test site
function setupmodrails {
  echolog "* Configuring mod_rails/Apache"

  echolog "  ...disable apache default vhost/welcome screen"
  if [ $DISTRO == "redhat" ]; then
    [ -r /etc/httpd/conf.d/welcome.conf ] && mv -f /etc/httpd/conf.d/welcome.conf /etc/httpd/conf.d/welcome.conf.bak
  elif [ $DISTRO == "debian" ]; then
    a2dissite default >> "$DEBUG_LOG_FILE" 2>&1
    [ -e /etc/apache2/sites-enabled/000-default ] && rm -f /etc/apache2/sites-enabled/000-default
  fi

# See GEM_PATH_VESION set at the top, different w/ each major version of Ruby
  echolog "  ...add basic passenger config"
  echo "
LoadModule passenger_module /usr/local/lib/ruby/gems/$GEM_PATH_VERSION/gems/passenger-$MOD_RAILS_VERSION/buildout/apache2/mod_passenger.so
PassengerRoot /usr/local/lib/ruby/gems/$GEM_PATH_VERSION/gems/passenger-$MOD_RAILS_VERSION
PassengerDefaultRuby /usr/local/bin/ruby
RailsEnv production
#Tune these to suit your application
PassengerMaxPoolSize 2
PassengerMaxInstancesPerApp 2
PassengerPoolIdleTime 600" > $MOD_RAILS_CONFIG

if [[ "$DISTRO" == "debian" ]]; then
echo "<VirtualHost *:80>
      ServerAdmin webmaster@localhost
      # !!! Be sure to point DocumentRoot to 'public'!
      DocumentRoot /var/www/apps/testapp/public
      # So we can get the welcome aboard page:
      RailsEnv development
      <Directory /var/www/apps/testapp/public>
         # This relaxes Apache security settings.
         AllowOverride all
         # MultiViews must be turned off.
         Options -MultiViews
      </Directory>

	ErrorLog \${APACHE_LOG_DIR}/error.log

	# Possible values include: debug, info, notice, warn, error, crit,
	# alert, emerg.
	LogLevel warn

	CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>" > /etc/apache2/sites-available/testapp.conf
a2ensite testapp.conf
fi

if [[ "$DISTRO" == "redhat" ]]; then
echo "<VirtualHost *:80>
      ServerAdmin webmaster@localhost
      # !!! Be sure to point DocumentRoot to 'public'!
      DocumentRoot /var/www/apps/testapp/public
      # So we can get the welcome aboard page:
      RailsEnv development
      <Directory /var/www/apps/testapp/public>
         # This relaxes Apache security settings.
         AllowOverride all
         # MultiViews must be turned off.
         Options -MultiViews
      </Directory>
</VirtualHost>" >> /etc/httpd/conf/httpd.conf
fi 

  echolog "  ...create app deployment directory" # FIXME?
  mkdir -p $RAILS_APP_DEPLOYMENT_DIR

  echolog "  ...create '$RAILS_TEST_APP' rails app"
  cd $RAILS_APP_DEPLOYMENT_DIR
  rails new "$RAILS_TEST_APP" -f >> "$DEBUG_LOG_FILE" 2>&1

  echolog "  ...fixing correct permissions for apache"
  if [[ "$DISTRO" == "redhat" ]]; then
    chown -R apache $RAILS_APP_DEPLOYMENT_DIR
  elif [[ "$DISTRO" == "debian" ]]; then
    chown -R www-data $RAILS_APP_DEPLOYMENT_DIR
  fi

  echolog "  ...enabling therubyracer JavaScript runtime"
  sed -i '/therubyracer/ s/^# //' $RAILS_APP_DEPLOYMENT_DIR/$RAILS_TEST_APP/Gemfile

  echolog "  ...restart apache"
  initcmd="service httpd"
  [ -e /etc/init/apache2 ] && initcmd="service apache2"
  [ -e /etc/init.d/apache2 ] && initcmd="/etc/init.d/apache2"
  $initcmd restart >> "$DEBUG_LOG_FILE" 2>&1
}

function footer {
  [[ "$CALLER" == "-bash" ]] || return 0
  ipaddr="$(ifconfig eth0 | grep "inet addr:" | awk '{print $2}' | cut -d: -f2)"
  echolog "* Ruby is now installed. You should see a testapp deployed here:"
  echolog "  http://$ipaddr/"
  echolog "  An Apache VirtualHost config was added here:"
if [ "$DISTRO" == "redhat" ]; then 
  echolog "  /etc/httpd/conf/httpd.conf"
elif [ "$DISTRO" == "debian" ]; then
  echolog "  /etc/apache2/sites-available/testapp.conf"
fi
  echolog "  DocumentRoot ($RAILS_APP_DEPLOYMENT_DIR/$RAILS_TEST_APP)"
  exit 0
}

####################
#    EXECUTION     #
####################

version
# APT update and install prereq packages
if [ -z "$NOAPT" ]; then
  aptgetupdate
  installprereqpackages
else
  echo "* Skipping Updates and installing Prereqs"
fi
# IMAGEMAGICK package or source install? 
if [ -z "$PACKMAGICK" ]; then
  echo "* not setting up ImageMagick from a package, check if source install requested" 
else
  if [ $DISTRO == "debian" ]; then
  $PKGMNGR install imagemagick >> "$DEBUG_LOG_FILE" 2>&1
  elif [ $DISTRO == "redhat" ]; then
  $PKGMNGR install ImageMagick >> "$DEBUG_LOG_FILE" 2>&1
  fi
  NOMAGICK=1
fi

if [ -z "$NOMAGICK" ]; then
  installimagemagik
else
  echo "* Skipping ImageMagick source install"
fi

# Regular Ruby or REE
[ -z "$USEREE" ] && installruby || installree

if [ -z "$USEREE" ] && [ -z "$OLDRUBY" ]; then
# If your installing REE then you won't need this:
  installrubygems 
else
  echo "* Skipping GEM install."
  echo " ...If you are using an old version of RUBY or REE you will probably want an older version"
fi

# Common Gems? 
if [ -z "$NOGEMINST" ]; then
  installcommongems
else 
  echo "* Skipping adding some common Gems"
fi

if [ -z "$NOMODPASSENGER" ]; then
 setupmodrails 
else 
  echo "* Skipping mod-passenger setup"
fi

footer

exit 0
