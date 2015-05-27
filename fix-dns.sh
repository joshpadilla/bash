#!/bin/bash

#
# $Id: fixdns 400 2014-10-02 06:33:28Z root $
#
# Recursive/Caching Nameservers
#

# - Dallas, Standard Network
nsc_dl1="72.249.191.254"
# Dallas, Premium Network
nsc_dl2="206.123.113.254"
# New York
nsc_ny1="66.199.228.254"
# London
nsc_ln1="92.48.122.126" 
# Australia
nsc_au1="122.100.15.254"

bad_nameservers=(
118.127.6.7
118.127.6.6
60.234.2.2
60.234.1.1 
206.123.64.245
206.123.69.4
72.29.96.250
207.210.212.202
72.249.0.34
206.123.69.254
66.199.228.130
206.123.113.132
207.99.0.41
207.99.0.42
207.99.0.1
207.99.0.2
66.199.235.50
72.9.108.146
210.56.80.56 
202.60.64.6 
203.25.185.119 
202.60.64.7
4.2.2.2
4.2.2.1
) 

au_nameservers="$nsc_au1 $nsc_dl1"
ln_nameservers="$nsc_ln1 $nsc_dl1 $nsc_ny1"
ny_nameservers="$nsc_ny1 $nsc_dl1 $nsc_ln1"
dl_nameservers="$nsc_dl1 $nsc_dl2 $nsc_ny1 $nsc_ln1"
ak_nameservers="$nsc_au1 $nsc_dl1"
syd_nameservers="$nsc_au1 $nsc_dl1"
google_nameservers="8.8.8.8 8.8.4.4"

ny_ranges="63. 66.199. 72.9. 216."
ln_ranges="85. 94. 217. 92."
au_ranges="202. 122. 117. 103. 49. 101.234."
dl_ranges="206.123. 207.210. 65.99. 72.249. 72.29. 74.50."
google_ranges=""

eth0=$(/sbin/ifconfig eth0 | grep 'inet addr' | cut -f2 -d: | awk '{print $1}')

if [[ -e /etc/resolveconf ]]; then
  echo "WARN: server appears to have the resolvconf package installed, that may"
  echo "      override your changes. Consider uninstalling that then reruning"
  echo "      this script?"
  exit 0
fi

if [ ! -e /etc/resolv.conf  ] ; then 
  echo "No /etc/resolv.conf file" >&2
  exit 1
fi

if [ ! -w /etc/resolv.conf  ] ; then 
  echo "No write permission to /etc/resolv.conf file.  Run as root?" >&2
  exit 1
fi


function usage() {
  echo "$0 [--dc ny|ln|au|dl|google] [--nameservers "8.8.8.8 8.8.4.4"] [--removebad] [--help] [--[no]check]"
}

while [ -n "$1" ]; do
  case "$1" in
  --dc)
  [ $# -lt 1 ] && echo "--dc value required" >&2 && exit 1
  shift
  eval good_nameservers=\$\{${$1}_nameservers\}
  echo "Using name servers for this location $1 are $good_nameservers" 
  ;;
  --nameservers)
  [ $# -lt 1 ] && echo "--nameserver value required" >&2 && exit 1
  shift
  good_nameservers=$1
  ;;
  --removebad)
  REMOVEBAD="Y"
  ;;
  --nocheck)
  CHECK="N"
  ;;
  --check)
  CHECK="Y"
  ;;
  --help|-?)
  usage
  exit 0
  ;;
  *)
  echo "Unexpected argument $1" >&2 && exit 1
  ;;
  esac
  shift
done

known_range="unknown"
for dc in ny ln au dl; do 
  [ -n "$good_nameservers" ] && break
  eval ranges=\$\{${dc}_ranges\}
  for range in $ranges; do
    if [ $(echo $eth0 | grep -c ^$range) -gt 0 ]; then
      eval good_nameservers=\$\{${dc}_nameservers\}
      echo "Default name servers for this location $dc are $good_nameservers" 
      break
    fi
  done
done

[ -z "$good_nameservers" ] && good_nameservers=$google_nameservers

#echo "Default name servers for this location are $good_nameservers"
#good_nameservers=($(echo "$good_nameservers"))
#echo "Default name servers for this location are $good_nameservers"

[ -e /etc/resolv.conf ] || exit 1

old="/etc/resolv.conf.rimu-$$"
cp /etc/resolv.conf $old

if ! which dig >/dev/null 2>&1 ; then echo "dig not installed, exiting." ; exit 1; fi 
if [ -n "$REMOVEBAD" ]; then
  nameservers=$(cat /etc/resolv.conf | grep '^nameserver' | awk '{print $2}')
  for server in $nameservers; do 
    if [ $(dig @${server} +short google.com | grep -v '^;' | wc -l) -le 1 ]; then 
      bad_nameservers+=($server)
      echo "$server is not responding, will remove."
    fi
  done
fi

count=0
for ((i=0;i<${#bad_nameservers[@]};i++)); do
  ns=${bad_nameservers[$i]}
  if [ $(grep -c "^nameserver $ns" /etc/resolv.conf) -gt 0 ]; then
    sed s/"^nameserver $ns"/"#nameserver $ns"/g --in-place /etc/resolv.conf
    if [ $? -ne 0 ]; then
      exit 1
    fi
    ((count++))
    echo "Removing $ns"
  fi
done

# If there is less than 2 nameservers listed in resolv.conf, and we're going to add less than 2
if [ $(grep -c '^nameserver' /etc/resolv.conf ) -lt 2 -a ${count} -lt 2 ]; then
  count=2
fi

for ns in $good_nameservers; do
  # need more name servers? 
  if [ $count -lt 1 ]; then break; fi
  # name server already listed?
  if [ $(grep -c "^nameserver $ns" /etc/resolv.conf) -gt 0 ]; then
    continue;
  fi
  # name server working?
  if [ $(dig @${ns} +short google.com | grep -v '^;' | wc -l) -le 1 ]; then
    continue;
  fi
  # add name server
  echo "nameserver $ns" >> /etc/resolv.conf
  # one fewer name server needed
  ((count--))
done

if [ $(grep -c '^nameserver' /etc/resolv.conf ) -lt 2 -a $(grep -c '^nameserver 8.8.8.8' /etc/resolv.conf ) -eq 0 ]; then
  echo "nameserver 8.8.8.8" >> /etc/resolv.conf 
fi

if [ $(grep -c '^nameserver' /etc/resolv.conf ) -lt 2 -a $(grep -c '^nameserver 8.8.4.4' /etc/resolv.conf ) -eq 0 ]; then
  echo "nameserver 8.8.4.4" >> /etc/resolv.conf 
fi

# show any changes.  if none remove the old file
diff $old /etc/resolv.conf || rm -f $old

retcode=0
goodns=0
if [ "N" == "$CHECK" ] ; then 
  echo "Skipping checks"
else 
  echo "Checking your name servers:"
  nameservers=$(cat /etc/resolv.conf | grep '^nameserver' | awk '{print $2}')
  for server in $nameservers; do 
    if [ $(dig @${server} +short google.com | grep -v '^;' | wc -l) -le 1 ]; then 
      echo "$server in /etc/resolv.conf is not working.  Rerun this script with --removebad to remove that."
      ((retcode++))
      continue
    fi 
	((goodns++))
    echo $server is working; 
  done
fi

if [ $goodns -lt 1 ] ; then
	((retcode++))
fi
# else breaks wget script | bash
exit $retcode

#example from lenny, dont use 'host', is no longer consistent output across distros. 'dig' is better
#dcs:~# host google.com
#google.com              A       74.125.225.98
#google.com              A       74.125.225.97
#google.com              A       74.125.225.101
#google.com              A       74.125.225.110
#google.com              A       74.125.225.100
#google.com              A       74.125.225.105
#google.com              A       74.125.225.102
#google.com              A       74.125.225.103
#google.com              A       74.125.225.96
#google.com              A       74.125.225.99
#google.com              A       74.125.225.104

