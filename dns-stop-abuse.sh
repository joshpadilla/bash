#!/bin/sh

#for i in ns1 ns2 ns3 ns4; do ssh $i.zonomi.com "mkdir -p /usr/local/sbin; /etc/init.d/firewall restart"; scp dns-stop-abuse.sh $i.zonomi.com:/usr/local/sbin/; done
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

oldprocs=$(ps auxf | grep '[t]cpdump' | grep 'and port 53' | awk '{print $2}')
[ ! -z "$oldprocs" ] && echo "Found old tcpdump commands running, stopping them: $oldprocs" && kill $oldprocs
# find servfail responses.  indicating we are being given requests for domains we are not setup for.
/usr/sbin/tcpdump -ni eth0 port 53 -c 10000 2>/dev/null | grep -i ServFail | awk '{print $5}' | cut -d '.' -f 1-4 | sort | uniq -c | sort -n | tail -n 10 | while read C IP; 
do
 # limit only to what looks like abuse
 [ $C -lt 50 ] && continue
 iptables -L -n | grep -qai " $IP " && continue
#21:26:57.265940 IP 8.0.24.190.59877 > 94.76.200.250.53: 11335% [1au] A? chopsuwey.biz. (42)

domains=$(/usr/sbin/tcpdump  -n src $IP and port 53 -c 50 | sed 's/.*?\(.*\). .*/\1/' | sort | uniq -c | sort -n | awk '{print $2}')

#log the reason and domains in the drop rule
/sbin/iptables -I INPUT -s $IP -j DROP -m comment --comment "servfails $C $(echo $domains)"; 

done

exit 0

