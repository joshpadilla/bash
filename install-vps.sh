#!/bin/bash
#
# Copyright Rimuhosting.com
# Created 26th Jul 2012
#

###
# Function: version
# Tell us what version the script is
#
function version {
echo " $0 (v1.5 $Id: newvps.sh 001 2012-08-13 17:51:00Z paul $)
Copyright Rimuhosting.com"
}

#
# Function: usage
# Handy function to tell users whats what
# 

function usage {
echo " Usage: $0 [--hostname hostname] [--memory 2048] [--disk 10240] [--password password] [--arch (i386|amd64)] [--apikey X] [--image URL] [--billingoid X] [--reinstall OID]

Option notes (* Required options):
* --hostname:       VPS hostname
* --memory:         VPS memory allocation (in MB)
* --disk:           VPS disk space allocation (in MB)
* --password:       VPS root password
* --arch:           VPS Architechure (i386 or amd64)
* --image:          URL to filesystem image to be used by the installer
* --apikey:         Your server api key, see https://rimuhosting.com/cp/apikeys.jsp for keys
* --billingoid      Your perfered billing method, see https://rimuhosting.com/cp/billingdetails.jsp for oids
  --reinstall:      Reinstall server with order id OID

Example to setup a new VPS, This would install test.example.com VPS on a shared VPS host with your custom image.

./newvps.sh --hostname test.example.tla --memory 1024 --disk 6144 --password password --arch amd64 --apikey X --billingoid X --image URL"
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
-h|help|-help|--help|?|-?|--?)
version
usage
exit 1;
;;
--hostname)
shift
VPS_HOSTNAME=$1
;;
--memory)
shift
VPS_MEMORY=$1
;;
--disk)
shift
VPS_DISK=$1
;;
--password)
shift
VPS_ROOTPW=$1
;;
--arch)
shift
ARCH=$1
;;
--image)
shift
IMAGE=$1
;;
--reinstall)
shift
VPS_OID=$1
;;
--apikey)
shift
# API Key, per https://rimuhosting.com/cp/apikeys.jsp (server)
APIKEY=$1
;;
--billingoid)
shift
BILLINGOID=$1
;;
*)
echo "unrecognised paramter '$PARAM'"
exit 0
;;
esac
shift
done

if [ ! $VPS_HOSTNAME ]
then
echo "Require VPS hostname, use --hostname or see --help for details"
exit 0
fi
if [ ! $VPS_MEMORY ]
then
echo "Require VPS memory, use --memory or see --help for details"
exit 0
fi
if [ ! $VPS_DISK ]
then
echo "Require VPS disk space, use --disk or see --help for details"
exit 0
fi
if [ ! $VPS_ROOTPW ]
then
echo "Require VPS root password, use --password or see --help for details"
exit 0
fi
if [ ! $ARCH ]
then
echo "Require VPS architecture, use --arch i386 or see --help for details"
exit 0
elif [ $ARCH == "i386" ]
then
DISTRO="squeeze"
elif [ $ARCH == "amd64" ]
then
DISTRO="squeeze.64"
fi
if [ ! $APIKEY ]
then
echo "Require API Key, use --apikey or see --help for details"
exit 0
fi
if [ ! $BILLINGOID ]
then
echo "Require BILLINGOID, use --billingoid or see --help for details"
exit 0
fi
if [ ! $IMAGE ]
then
echo "Require an IMAGE URL, use --image or see --help for details"
exit 0
else
FILE=`echo ${IMAGE} | awk -F"/" '{print $NF }'`
PATH="/root"
fi
if [ $VPS_OID ]
then
  METHOD="PUT"
  URL="https://rimuhosting.com/r/orders/order-${VPS_OID}-asdf/vps/reinstall"
else
  METHOD="POST"
  URL="https://rimuhosting.com/r/orders/new-vps"
fi

}

function vps_install {

SCRIPTPRE="#!/bin/bash -x

mkdir -p /media/root
mount -t tmpfs -o size=1024m tmpfs /media/root
cd /
cp -a bin boot etc home lib lib64 lost+found mnt opt root sbin selinux srv tmp usr var /media/root/
cd /media/root
mkdir -p dev media sys proc

pivot_root . mnt
mount -t proc proc /proc
mount -t sysfs sys /sys
mount -t tmpfs dev /dev
/etc/init.d/udev start
umount /mnt/proc
umount /mnt/sys
umount /mnt/dev
chattr -R -i /mnt/*
rm -Rf /mnt/*

cd /mnt

if file $PATH/$FILE | grep bzip2 &gt;/dev/null ; then
  tar -jxvf $PATH/$FILE
elif file $PATH/$FILE | grep gzip &gt;/dev/null ; then
  tar -zxvf $PATH/$FILE
elif file $PATH/$FILE | grep zip &gt;/dev/null ; then
  unzip $PATH/$FILE
elif file $PATH/$FILE | grep iso &gt;/dev/null ; then
  mkdir -p /media/iso
  mount -o loop $PATH/$FILE /media/iso
  cp -a /media/iso/* .
  umount /media/iso
else
  echo \"$PATH/$FILE is not a valid file\"
fi"

SCRIPT1=`echo "$SCRIPTPRE" | /usr/bin/base64 -w 0 -`

  echo Installing ${VPS_HOSTNAME} ..
  DATA="{'new_order_request':{'is_just_minimal_init':'Y','billing_oid':'${BILLINGOID}','instantiation_options':{'domain_name':'${VPS_HOSTNAME}','password':'${VPS_ROOTPW}','distro':'${DISTRO}'},'vps_parameters':{'disk_space_mb':'${VPS_DISK}','memory_mb':'${VPS_MEMORY}'},'file_injection_data':[{'data_from_url':'${IMAGE}','exec_on_first_boot':0,'path':'/root/${FILE}'},{'data_as_base64':'${SCRIPT1}',exec_on_first_boot':1,'path':'/root/custominstall.sh'}]}}"
  /usr/bin/curl -X ${METHOD} \
       -H "Content-Type: application/json" \
       -H "Accept: application/json" \
       -H "Authorization: rimuhosting apikey=$APIKEY" \
       --data "${DATA}" \
       -m 1800 \
       "${URL}"
}

parsecommandline $*
vps_install
