#!/bin/bash
# chkconfig: 2345 08 92
# description: iptables start/stop/restart script
#
### BEGIN INIT INFO
# Provides:          firewall
# Required-Start:    $network 
# Required-Stop:     $network 
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: iptables start/stop/restart script
### END INIT INFO
#
# $Id: firewall 355 2014-03-04 01:27:24Z glenn $
#
### Set these to match your setup. ###

# TCP ports to allow
allow_tcp="22 25 80 443"

# UDP ports to allow
allow_udp=""

# ICMP types to allow
allow_icmp="echo-reply destination-unreachable source-quench parameter-problem time-exceeded"

# This machines IP addresses
my_ips=""

# IP addresses to whitelist
allow_ips=""

# Allow ICMP echo-request aka pings
allow_ping=true

# Open UDP ports for traceroute and allow ICMP 
allow_traceroute=true

# Allow connections to FTP port and related ports
# ProFTPd: please include "PassivePorts 49152 65534" in your conf file
#          as per http://www.proftpd.org/docs/directives/linked/config_ref_PassivePorts.html
allow_ftp=true
ftp_ports="20,21,49152:65534"

# Some mail servers try to probe the ident port. Rejecting these (rather than dropping) speeds things up
reject_ident=true

### Script starts ###

iptables=$(which iptables)
#iptables_modules="ip_tables ip_conntrack ip_conntrack_ftp"

if [ -e /etc/firewall.conf ]; then
	source /etc/firewall.conf
fi

if [ -z "$iptables" ]; then
	echo "iptables not found in $PATH. Exiting."
	exit 1
fi

function start() {
	echo "* Starting firewall ..."	

	if [ -n "$iptables_modules" ]; then
		for module in $iptables_modules; do
			/sbin/modprobe $module
			if [ $? -ne 0 ]; then
				echo "Failed to mobprobe $module. Exiting."
				exit 1
			fi
		done
	fi

	flush
	set_policy DROP
	
	# Disable ICMP broadcast replys from this box
	/bin/echo "1" > /proc/sys/net/ipv4/icmp_echo_ignore_broadcasts

	# Disable ICMP redirect
	/bin/echo "0" > /proc/sys/net/ipv4/conf/all/accept_redirects 

	# Enable bad error message protection
	/bin/echo "1" > /proc/sys/net/ipv4/icmp_ignore_bogus_error_responses 
	 
	# Log spoofed packets, source routed packets, redirect packets. 
	/bin/echo "1" > /proc/sys/net/ipv4/conf/all/log_martians 

	# Disable Congestion Notification

	/bin/echo "0" > /proc/sys/net/ipv4/tcp_ecn

	# Turn off IP Forwarding
	echo 0 > /proc/sys/net/ipv4/ip_forward

	# accept ourselves (loopback and localnet)
	$iptables -A INPUT -i lo -j ACCEPT
	for ip in $my_ips; do
		$iptables -A INPUT -s $ip -j ACCEPT
	done

	# Let new connections in
	$iptables -A INPUT -p tcp ! --syn -m state --state NEW -j DROP

	# Accept traffic with the ACK flag set
	#$iptables -A INPUT -p tcp -m tcp --tcp-flags ACK ACK -j ACCEPT
	# Allow incoming data that is part of a connection we established
	#$iptables -A INPUT -m state --state ESTABLISHED -j ACCEPT
	# Allow data that is related to existing connections
	#$iptables -A INPUT -m state --state RELATED -j ACCEPT
	$iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT 

	# Allow traffic from whitelisted IPs
	if [ -n "$allow_ips" ]; then
		echo -n "  Whitelisting IPs: "		
		for ip in $allow_ips; do
			echo -n "$ip "
			$iptables -A INPUT --source $ip -j ACCEPT
		done
		echo ""
	fi

	echo "  Opening Ports"
	if [ -n "$allow_tcp" ]; then
		echo -n "    TCP: "
		for port in $allow_tcp; do
			echo -n "$port "
			$iptables -A INPUT -p tcp --dport $port -j ACCEPT
		done
		echo ""
	fi

	if [ -n "$allow_udp" ]; then
		echo -n "    UDP: "
		for port in $allow_udp; do
			echo -n "$port "
			$iptables -A INPUT -p udp --dport $port -j ACCEPT
		done
		echo ""
	fi

	if [ -n "$allow_icmp" ]; then
		echo -n "    ICMP: "
		for type in $allow_icmp; do
			$iptables -A INPUT -p icmp -m state --state ESTABLISHED,RELATED  --icmp-type $type -j ACCEPT
			echo -n "$type "
		done
		echo ""
	fi

	# Special cases
	
	if [ "$allow_ftp" = "true" ]; then
		echo "  Allowing FTP and related ports ($ftp_ports)"
		$iptables -A INPUT -p tcp -m multiport --dports $ftp_ports -j ACCEPT
		$iptables -A INPUT -p udp -m multiport --dports $ftp_ports -j ACCEPT
	fi

	if [ "$reject_ident" = "true" ]; then
		echo "  Rejecting IDENT/tcp113 requests with tcp-reset"
		$iptables -A INPUT -p tcp --dport 113 -j REJECT --reject-with tcp-reset
	fi

	if [ "$allow_ping" = "true" ]; then
		echo "  Allowing ICMP echo-request for pings"
		$iptables -A INPUT -p icmp -m icmp --icmp-type echo-request -j ACCEPT
	fi

	if [ "$allow_traceroute" = "true" ]; then
		echo "  Allowing UDP 33434:33523 and ICMP time-exceeded for traceroute"
		$iptables -A INPUT -p icmp -m icmp --icmp-type time-exceeded -j ACCEPT
		$iptables -A INPUT -p udp -m udp --dport 33434:33523 -j ACCEPT
	fi
	
	echo "* Firewall up."
}

function stop() {
	echo "* Stopping firewall ... "
	flush
	set_policy ACCEPT
	echo "* Firewall stopped."
}

function flush() {
	echo -n "  Flushing tables ... "
        $iptables -F
	$iptables -X
	$iptables -Z
	echo "Done"
}

function set_policy() {
	local policy="$1"
	echo -n "  Setting default policy to $1 ... "
  	$iptables -P INPUT $policy
	$iptables -P FORWARD $policy
	$iptables -P OUTPUT ACCEPT
	echo "Done"
}

case "$1" in
    start)
        start
        ;;
    stop)
        stop
		;;
    restart)
		stop
		start
		;;
    *)
		echo "Usage: $0 {start|stop|restart}"
		exit 1
		;;
esac

