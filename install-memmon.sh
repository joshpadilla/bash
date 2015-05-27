#!/bin/bash

#
# $Id: installmemmon.sh 364 2014-03-21 23:48:11Z root $
#

SCRIPT=/usr/local/bin/memmon.sh
LOG=/var/log/memmon.txt
cat << EOF > $SCRIPT
#!/bin/bash
date; uptime; free -m;
df -h
vmstat 1 5
[ -x /usr/sbin/iotop ] && iotop -o -b -d 3 -n 2  -k 2>/dev/null  | awk '{print "iotop: " $0}'
ps axfww -o ruser,pid,%cpu,%mem,stat,time,cmd
if which iptables 2>&1 > /dev/null; then
  if [ -e /tmp/iptables_default ]; then
    iptables -L -n | diff /tmp/iptables_default - | awk '{print "IPTABLES: " \$0}'
  fi
  iptables -L -n > /tmp/iptables_default
fi
if [ -e /tmp/dmesg_default ]; then
	dmesg | diff -u /tmp/dmesg_default - | grep '^+' | awk '{print "DMESG:" \$0}'
fi
dmesg > /tmp/dmesg_default
EOF

chmod +x $SCRIPT

# create a cronjob that runs every few minutes to log the memory usage
echo "0-59/10 * * * * root $SCRIPT >> $LOG" > /etc/cron.d/memmon
/etc/init.d/cron* restart

# create a logrotate entry so the log file does not get too large
echo "$LOG {}" > /etc/logrotate.d/memmon
