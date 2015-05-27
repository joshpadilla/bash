#!/bin/bash

#
# $Id: checkphpmyadmin.sh 21 2010-11-18 09:37:16Z deploy $
#
# This script scans the target server for phpMyAdmin installations.
# It can be run in either update or check mode.  Check mode will print
# out information, but will not perform any changes to the target server.
# Output is logged to /root/fixphpmyadmin.log.
#

###
# view std out and append to log
function echolog() {
        echo -e $* | tee -a /root/fixphpmyadmin.log
}

###
# usage
function usage() {
	echo "Usage:"
	echo "$0 <check|update>"
}

###
# plesk check - I do not trust fiddling with anything plesk-related
# here.  Probably best to detect and ask user to submit a ticket asking
# us to check that it's been handled via the plesk ui.  safety first
function detectplesk() {
	echolog "Checking for presence of Plesk."
	if [ -f /etc/psa/.psa.shadow ]; then
		echolog "Plesk detected - please submit support ticket or email us at support@rimuhosting and ask us to check that it has been patched."
		echolog "Exiting"
		exit 1
	else
		echolog "Plesk not detected"
	fi
}

###
# locate phpmyadmin installs and repair if flag is set
function locatemanually() {
	###
	# determine latest 2.x phpMyAdmin release number
	echolog "Attempting to parse latest 2.x phpMyAdmin release from http://www.phpmyadmin.net/home_page/downloads.php"
	PMAVERSION=`wget -q -O - "http://www.phpmyadmin.net/home_page/downloads.php" | grep "<h2>phpMyAdmin 2\." | awk '{print $2}' | cut -f1 -d\<`
	if [ `echo $PMAVERSION | grep 2\. | wc -l` -lt 1 ]; then
		echolog "Unable to parse phpMyAdmin version.  Exiting."
		exit 1
	else
		echolog "Current 2.x version detected is $PMAVERSION.  Using this release."
	fi
	##
	# loop through found phpmyadmin locations
	echolog "Looking for manual phpMyAdmin installs."
	for LOC in `find / -type d -iname 'phpmyadmin*'`; do 
		###
		# determine if version installed is old
		if [ -f $LOC/RELEASE-DATE-$PMAVERSION ]; then
			echolog "Installation at " $LOC "is $PMAVERSION.  No action required."
		else
			##
			# check that directory isn't a config or misc directory
			# skip remainder of loop if LICENSE is not found
			if [ ! -f $LOC/LICENSE ]; then
				echolog "$LOC does not appear to be a functional install.  Skipping"
				continue
			fi
			echolog "Installation at " $LOC "needs updated."
			if [ ! -z "$DOUPDATE" ]; then
				echolog "Performing update of $LOC"
				##
				# change into parent directory of install
				cd $LOC/..
				##
				# download if not already in directory
				if [ ! -f phpMyAdmin-$PMAVERSION-english.tar.gz ]; then
					echolog "Downloading phpMyAdmin $PMAVERSION from sourceforge"
					wget http://downloads.sourceforge.net/sourceforge/phpmyadmin/phpMyAdmin-$PMAVERSION-english.tar.gz?use_mirror=internap -o /dev/null
				else
					echolog "phpMyAdmin already downloaded.  Skipping download."
				fi
				##
				# verify file was downloaded
				if [ ! -f $LOC/../phpMyAdmin-$PMAVERSION-english.tar.gz ]; then
					echolog "Problem downloading phpMyAdmin.  Exiting"
					exit 1
				fi
				echolog "Decompressing phpMyAdmin"
				tar xfz phpMyAdmin-$PMAVERSION-english.tar.gz
				if [ ! $? -eq 0 ]; then
					echolog "Could not extract phpMyAdmin.  Exiting"
					exit 1
				fi				
				##
				# removing old phpmyadmin from server
				# check that $LOC at least contains index.php as this
				# command is dangerous
				if [ ! -f $LOC/index.php ]; then
					echolog "Removing $LOC from server."
					rm -rf $LOC
				fi
				if [ ! $? -eq 0 ]; then
					echolog "Could not remove phpmyadmin.  Exiting"
					exit 1
				fi
				##
				# move new phpmyadmin install into same location as original so that
				# apache directives do not need changed if somebody is using it as a docroot
				echolog "Moving phpMyAdmin $PMAVERSION into place and creating config file."
				mv phpMyAdmin-$PMAVERSION-english $LOC
				if [ ! -f $LOC/index.php ]; then
					echolog "Problem moving phpMyAdmin.  Exiting"
					exit 1
				fi
				##
				# setup config file
				random_chars=$(echo $(date) $(hostname) $(whoami) $(uname -a) | md5sum | cut -c1-10)
				cd $LOC		
cat << EOF > config.inc.php
<?php
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
\$cfg['blowfish_secret'] = '$random_chars';
?>
EOF
			else
				echolog "Not performing update as script was not run with update option.  Please rerun script to perform update."			
			fi
		fi		
	done
	echolog "Done."
	exit 0
}

###
# basic distro specific routines
function dodistroroutine() {
	##
	# check for plesk
	detectplesk
	##
	# detect distro
	echolog "Attempting to determine distro type.  (RedHat or Debian based.)"
	if [ -e /etc/redhat-release ]; then
		ISREDHAT="1"
		echolog "Distro is RedHat based."
	elif [ -e /etc/debian_version ]; then
		ISDEBIAN="1"
		echolog "Distro is Debian based."
	else
		echolog "Unable to determine distro.  Exiting script."
		exit 1
	fi
	if [ ! -z "$ISDEBIAN" ]; then
		##
		# check if installed via package manager
		echolog "Checking if phpMyAdmin is installed via apt-get."
		ISPACKAGEINSTALLED=`dpkg --get-selections | grep phpmyadmin | grep -v deinstall | wc -l`
		##
		# if package install then update via apt-get
		if [ $ISPACKAGEINSTALLED = '1' ]; then
			echolog "Performing apt-get update of package"
			apt-get update 
			apt-get -y --force-yes install phpmyadmin
			if [ ! $? -eq 0 ]; then
				echolog "apt-get update failed.  Exiting"
				exit 1
			fi
		else
			echolog "phpMyAdmin not installed via apt-get.  Skipping apt-get update."
		fi
		##
		# check if manually installed
		locatemanually
	elif [ ! -z "$ISREDHAT" ]; then
		##
		# check if manually installed
		locatemanually
	fi
}

##
# display usage if no command line options are entered
if [ -z $1 ]; then
	usage
	echo "No option selected"
	exit 1
fi

###
# parse command line options and display usage instructions if there is a problem
while [ ! -z "$1" ]; do
	case "$1" in
	check)
		dodistroroutine
		break
	;;
	update)
		DOUPDATE="1"
		dodistroroutine
		break
	;;
	*)
		usage
		exit 1
	;;
	esac
done

exit 0
