#!/bin/bash

# for i in 122.100.15.254 206.123.113.254 72.249.191.254 92.48.122.126 66.199.228.253; do scp dnsratelimiter $i:/etc/cron.hourly/; done
# logs people doing large dns query volumes.
# blocks them if it looks like they are not 'one of our' IPs

#wheezy/rsyslogd needs:  /etc/rsyslog.d/dnsratelimiter.conf 
echo ' 
:msg, startswith, "ratelimit:" -/var/log/iptables.log
& ~
' > /dev/null


rnratelimit=$(iptables -n -v --line-numbers -L INPUT | grep ratelimit | awk '{print $1}' | head -n 1)
if [ -z "$rnratelimit" ] ; then 
  rnafter=$(iptables -n -v --line-numbers -L INPUT | grep ACCEPT | awk '{print $1}' | head -n 1)
  if [ -z "$rnafter" ] ; then echo "Could not find accept rule">&2; exit 1; fi
  iptables -I INPUT $rnafter -p tcp  -m multiport --port  53 -m hashlimit    --hashlimit-name DNS --hashlimit-above 30/minute --hashlimit-mode srcip --hashlimit-srcmask 28 -j LOG --log-level 4 --log-prefix "ratelimit:"
  iptables -I INPUT $rnafter -p udp  -m multiport --port  53 -m hashlimit    --hashlimit-name DNS --hashlimit-above 30/minute --hashlimit-mode srcip --hashlimit-srcmask 28 -j LOG --log-level 4 --log-prefix "ratelimit:"
  if [ $? -gt 0 ] ; then echo "Could not add log rule">&2; exit 1; fi
fi
if [ "$1" != "--nocollect" ]; then
  echo "Collecting stats"
  for i in 1; do 
    if [ -e /var/log/iptables.log ] ; then if [ $(wc -l /var/log/iptables.log | awk '{print $1}') -gt 0  ]; then
      echo "" > /var/log/iptables.log
      sleep 70
      break
      fi
    fi
    sleep 10
  done
fi

rnratelimit=$(iptables -n -v --line-numbers -L INPUT | grep ratelimit | awk '{print $1}' | head -n 1)
if [ -z "$rnratelimit" ] ; then echo "Could not find log rule">&2; exit 1; fi
iptables -D INPUT $rnratelimit
rnratelimit=$(iptables -n -v --line-numbers -L INPUT | grep ratelimit | awk '{print $1}' | head -n 1)
if [ ! -z "$rnratelimit" ]; then iptables -D INPUT $rnratelimit; fi
echo "Processing stats"

for i in 1 ; do 
  if [ -e /var/log/iptables.log ] ; then if [ $(wc -l /var/log/iptables.log | awk '{print $1}') -gt 0  ]; then

    cat /var/log/iptables.log  | grep 'ratelimit:' | awk '{print $9}' | sed 's/SRC=//' | sort | uniq -c | sort -n  | egrep  '^ *[0-9]{2,} |^ *[4-9] ' | awk '{print $1 " " $2}' 
    break
  fi
  fi
  dmesg | grep 'ratelimit:' | awk '{print $4}' | sed 's/SRC=//' | sort | uniq -c | sort -n  | egrep  '^ *[0-9]{2,} |^ *[4-9] ' | awk '{print $1 " " $2}' 
done | while read hits i; do
  iptables -L -n | grep -q " $i " && continue; 
  echo $i | grep -q "127.0.0" && continue
  echo $i | grep -q "74\.50\." && continue
  echo $i | grep -q "74\.249\." && continue
  for iw in 1 2 3 4 5 6; do
    whois $i > /tmp/dnslimiterwhois
    if grep -qai 'ERROR' /tmp/dnslimiterwhois ; then echo temp whois busy >&2; echo "" > /tmp/dnslimiterwhois; continue; fi
    if [ $? -ne 0 -a  $(wc -l /tmp/dnslimiterwhois | awk '{print $1}') -lt 10 ]; then echo "temp whois failed #$iw" >&2 ; continue; fi 
    break
  done
  if [ $(wc -l /tmp/dnslimiterwhois | awk '{print $1}') -lt 10 ]; then echo "perm whois failed" >&2 ; continue; fi
  cat /tmp/dnslimiterwhois | egrep -qi 'INTERVO|OZSERVERS|COLO4|RIMUH|HDNETNZ|SOCIALSTRATA|Poundhost|EZZI|HOSTINGDIRECT|gnax|SOFTLAYER|COREIX|PH-NETWOR|BlueSquare|EDICATEDSERVERS-A|Simply Transit' && continue; 
  netname=$(cat /tmp/dnslimiterwhois | egrep -i 'netname' | head -n 1)
  hits=$(dmesg | grep 'ratelimit:' | grep -c "=$i " )
  echo "iptables '$i'"; iptables -I INPUT -s $i -j DROP -m comment --comment "at $(date +%s) $hits hits from $netname"
done
