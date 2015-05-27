#!/bin/bash

# Copyright Rimuhosting.com

# simple cron script to check disk space and send notifications


#cd $(dirname $0) && pwd


if [ "$(cd $(dirname $0) && pwd)" != "/etc/cron.hourly" ]; then
	echo "Warning: script should be located in /etc/cron.hourly for periodic checks"
fi



CONFIG_FILE=/etc/check-disk-space.conf




if ! [ -e $CONFIG_FILE ]; then
	echo <<EOF >$CONFIG_FILE  '# config

# minimunm disk space free
# can be specified in percent (% char at the end, no spaces) or number of 1K blocks
MIN_DISK_FREE=3145728

# send an alert every time the script is executed and this value has been exceeded
# can be specified in percent (% char at the end, no spaces) or number of 1K blocks
# should be less than the above value if required to be active.
MIN_DISK_FREE_PANIC=524288

# reminder interval, in seconds, big value like 9999999999 for "disable".
# reminder is sent if min disk free is still exceded and the interval has passed.
REMINDER_INTERVAL=86400

# send alert mail message every time the script is executed, no matte what, good for testing and debugging
SEND_EVERY_TIME=0

# where to send the alert
MAIL_TO="root@localhost"

# mail subject, carefull with the quotation
MAIL_SUBJECT="$(hostname -f) is running low on disk space"

# mail message, carefull with the quotation
MAIL_MESSAGE="host: $(hostname -f)
minimun required disk free value (1K blocks / %): $MIN_DISK_FREE
$(df -h)

the server is running low on disk space.  Maybe there are some large logs to remove, or the disk needs resizing."

# vars to keep track of the change, no need to change the following
TRIGGERED=0
LAST_MAIL_SENT=0
'
EOF

fi

if ! [ -e $CONFIG_FILE ]; then
	echo "ERROR: config file $CONFIG_FILE does not exist"
	exit 1
fi

. /$CONFIG_FILE

if echo $MIN_DISK_FREE | grep -q '%$' && echo $MIN_DISK_FREE_PANIC | grep -q '%$'; then
	MIN_DISK_FREE=$(echo $MIN_DISK_FREE | sed 's/%$//g')
	MIN_DISK_FREE_PANIC=$(echo $MIN_DISK_FREE_PANIC | sed 's/%$//g')
	if [ $MIN_DISK_FREE -gt 100 ] || [ $MIN_DISK_FREE -lt 0 ]; then
		echo "ERROR: MIN_DISK_FREE has an incorrect percentange"
		exit 1
	fi
	if [ $MIN_DISK_FREE_PANIC -gt 100 ] || [ $MIN_DISK_FREE_PANIC -lt 0 ]; then
                echo "ERROR: MIN_DISK_FREE_PANIC has an incorrect percentange"
                exit 1
        fi
	if [ $MIN_DISK_FREE_PANIC -gt $MIN_DISK_FREE ]; then
		echo "ERROR: MIN_DISK_FREE_PANIC is greater than MIN_DISK_FREE"
		exit 1
	fi
	AVAILAIBLE_DISK=$[ 100 - $(df / | grep '/$' | head -n 1 | awk '{print $5}' | sed 's/%$//g') ]

elif echo $MIN_DISK_FREE | grep -qv '%$' && echo $MIN_DISK_FREE_PANIC | grep -qv '%$'; then
	if [ $MIN_DISK_FREE -lt 0 ]; then
		echo "ERROR: MIN_DISK_FREE has an incorrect value"
		exit 1
	fi
	if [ $MIN_DISK_FREE_PANIC -lt 0 ]; then
		echo "ERROR: MIN_DISK_FREE_PANIC has an incorrect value"
		exit 1
	fi
	if [ $MIN_DISK_FREE_PANIC -gt $MIN_DISK_FREE ]; then
                echo "ERROR: MIN_DISK_FREE_PANIC is greater than MIN_DISK_FREE"
                exit 1
        fi
	AVAILAIBLE_DISK=$(df / | grep '/$' | awk '{print $4}' | sed 's/%$//g')	

else
	echo "ERROR: MIN_DISK_FREE and MIN_DISK_FREE_PANIC should share the same type of configuration"
	exit 1
fi
	
if [ $AVAILAIBLE_DISK -lt $MIN_DISK_FREE ]; then
	if [ $AVAILAIBLE_DISK -lt $MIN_DISK_FREE_PANIC ] || [ $TRIGGERED = 0 ] || [ $SEND_EVERY_TIME = 1 ] || [ $[ $(date '+%s') - $LAST_MAIL_SENT ] -gt $REMINDER_INTERVAL ]; then
		echo "$MAIL_MESSAGE" | mail -s "$MAIL_SUBJECT" $MAIL_TO
		sed -i 's/^LAST_MAIL_SENT.*/LAST_MAIL_SENT='$(date '+%s')'/g' $CONFIG_FILE
	fi
	sed -i 's/^TRIGGERED.*/TRIGGERED=1/g' $CONFIG_FILE
else
	# it has been fixed
	if [ $TRIGGERED = 1 ]; then
		sed -i 's/^TRIGGERED.*/TRIGGERED=0/g' $CONFIG_FILE
	fi
fi
