#!/bin/bash


set_env(){
CHECK_ONLY=no
FORCE=no

PRIV_KEY_FILES="/etc/ssh/ssh_host_ecdsa_key"
PUB_KEY_FILES="/etc/ssh/ssh_host_ecdsa_key.pub"


ECDSA_FILES_FOUND=0


}



usage(){

	echo <<USAGE "
Usage: $(basename $0) [OPTION...]

$(basename $0) will attempt to identify if server has weak ecdsa keys, and regenerate them

Options:
-c Check only, do not perform any actions
-f Force the regeration if keys are found and they are not identified as offending ones
-h this help

"
USAGE
}



check_offending_md5(){
	OFFENDING_MD5S="fcdf63279f1354991c9144898ee73894 fbee338fb0875154b0ba9c591a65f83e 6abdaee625a4afb58abcaaa8b5e7f299 b3f143613f9be43a4bd53223953c37bf 772e90f17dfc7e32acb07ea349056b06 550723a7ca98fd79a06e2ca19355918d d8eb9aff7c97d0af7be5560b3b0b8003 abad971b4880260563bd9ed38943ae8a"	
	FILE=$1

	FILE_MD5=$(md5sum $FILE | awk '{print $1}')
	for m in $OFFENDING_MD5S; do
		if [ "$m" = "$FILE_MD5" ]; then
			echo "$i found in the blacklist, please regenerate key pair";
			return 1
		fi
	done
	return 0
}


check_offending_pub_key(){
	OFFENDING_PUB_KEYS="AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBGcvnJhojlRRTmwsx7+i2W/nqjEie/IWhlfyivNd8KCuo4klfczvhMx/Sljh+xhZTAfC/4ZAbNx5BuQmo7Y72g4= AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBGxD+vD24+U6i7UB6a4kkMtIq4KHuoZ1MyQcbpqqpXtFXViEEQnw53vLiSNQV579rcqlOVSklC+0YCrT5uZ1xPA= AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBJdawm1CLk98skFSmrw6HT4BZr2/zCI7AWDQeR8ZQnvtT7Fa7QizogZn1EYPR1aVdngre8m82QLnWYWreEfc0gY= AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBPV7DDUFRFaKzRCYDaoZsYnIYs9iMUZtLnyN/bplXHj/ZlyVLq4lny1PMfSumux6STmT5PUOfduYuF6qLIC8VL8="
	FILE=$1
	
	for pk in $OFFENDING_PUB_KEYS; do
		if grep -q $pk $FILE; then
			echo "$i found in the blacklist, please regenerate key pair";
                        return 1
		fi
	done
	return 0
}


# Mail code

set_env

while getopts 'cfh' option; do
	case $option in
	c)	CHECK_ONLY=yes;;
	f)	FORCE="yes";;
	h)	usage
		exit 0;;
	[?])	usage
		exit 1;;	
    esac
done


# do a check for something found at least

for i in $PRIV_KEY_FILES; do
	if [ -e "$i" ]; then
		ECDSA_FILES_FOUND=1
		echo "Private ecdsa keys found"
	fi
done

for i in $PUB_KEY_FILES; do
	if [ -e "$i" ]; then
		echo "Public ecdsa keys found"
		ECDSA_FILES_FOUND=1
	fi
done

if [ "$ECDSA_FILES_FOUND" -eq "0" ]; then
	echo "No ecdsa key pairs found, doing nothing"
	exit 0
else
	echo "Checking existing ecdsa key pairs"
fi


# check md5s for private keys files
for i in $PRIV_KEY_FILES; do
	if [ ! -e "$i" ]; then
		#file does not exist skipping
		continue
	fi	
	check_offending_md5 $i
	if [ "$?" -ne "0" ]; then
		echo "Found offending md5 key: $i"
		if [ "$CHECK_ONLY" = "no" ]; then
			FILE=$i
			echo "Regenerating key $FILE"
			rm -f $FILE
			/usr/bin/ssh-keygen -t ecdsa -f $FILE -N '' 
		fi
	fi

	
done

# check pub keys
for i in $PUB_KEY_FILES; do
	if [ ! -e "$i" ]; then
		#file does not exist skipping
		continue
	fi	
	check_offending_md5 $i
	if [ "$?" -ne "0" ]; then
		echo "Found offending md5 key: $i"
		if [ "$CHECK_ONLY" = "no" ]; then
			FILE=$(echo $i | sed 's/\.pub$//g')
			echo "Regenerating key $FILE"
			rm -f $FILE
			/usr/bin/ssh-keygen -t ecdsa -f $FILE -N '' 
		fi
	fi
	check_offending_pub_key $i
	if [ "$?" -ne "0" ]; then
		echo "Found offending pub key: $i"
		if [ "$CHECK_ONLY" = "no" ]; then
			FILE=$(echo $i | sed 's/\.pub$//g')
			echo "Regenerating key $FILE"
			rm -f $FILE
			/usr/bin/ssh-keygen -t ecdsa -f $FILE -N '' 
		fi
	fi
done


# force regenerations of privates found

if [ "$FORCE" = "yes" ]; then
	echo "Forcing the regeration of private keys found"
	for i in $PRIV_KEY_FILES; do
		if [ ! -e "$i" ]; then
                	#file does not exist skipping
	                continue
		fi
		echo "Regenerating key $i"
		rm -f $i
       		/usr/bin/ssh-keygen -t ecdsa -f $i -N ''	
	done
fi

