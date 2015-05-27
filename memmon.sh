#!/bin/bash

#
# $Id: memmon.sh 362 2014-03-19 20:59:07Z glenn $
#
# create a memmon.sh script that tracks the current date, memory usage and running processes
#

echo '#!/bin/bash' > /root/memmon.sh
echo "
date;
uptime
free -m
df -h
vmstat 1 5
ps auxf --width=200
" >> /root/memmon.sh

chmod +x /root/memmon.sh

# create a cronjob that runs every few minutes to log the memory usage
echo '0-59/10 * * * * root /root/memmon.sh >> /root/memmon.txt' > /etc/cron.d/memmon
/etc/init.d/cron* restart 

# create a logrotate entry so the log file does not get too large
echo '/root/memmon.txt {}' > /etc/logrotate.d/memmon
