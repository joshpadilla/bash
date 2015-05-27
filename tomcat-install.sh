#!/bin/bash

TOMCAT=apache-tomcat-7.0.23
TOMCAT_WEBAPPS=$TOMCAT/webapps
TOMCAT_CONFIG=$TOMCAT/conf/server.xml
TOMCAT_START=$TOMCAT/bin/startup.sh
TOMCAT_ARCHIVE=$TOMCAT.tar.gz
TOMCAT_URL=http://apache.mirrorcatalogs.com/tomcat/tomcat-7/v7.0.23/bin/$TOMCAT_ARCHIVE
WAR_FILE=whatever.war

if [ ! -e $TOMCAT ]; then
    if [ ! -r $TOMCAT_ARCHIVE ]; then
	if [ -n "$(which curl)" ]; then
	    curl -O $TOMCAT_URL
	elif [ -n "$(which wget)" ]; then
	    wget $TOMCAT_URL
	fi
    fi

    if [ ! -r $TOMCAT_ARCHIVE ]; then
	echo "Tomcat could not be downloaded." 1>&2
	echo "Verify that eiter curl or wget is installed." 1>&2
	echo "If they are, check your internet connection and try again." 1>&2
	echo "You may also download $TOMCAT_ARCHIVE and place it in this folder." 1>&2
	exit 1
    fi

    tar -zxf $TOMCAT_ARCHIVE
    rm $TOMCAT_ARCHIVE
fi

if [ ! -w $TOMCAT -o ! -w $TOMCAT_WEBAPPS ]; then
    echo "$TOMCAT and $TOMCAT_WEBAPPS must be writable." 1>&2
    exit 1
fi

if [ ! -r $WAR_FILE ]; then
    echo "$WAR_FILE is missing. Download it and run this again to deploy it." 1>&2
else
    cp $WAR_FILE $TOMCAT_WEBAPPS
fi

# place tomcat customizations here
sed -i s/8080/9090/g $TOMCAT_CONFIG

$TOMCAT_START