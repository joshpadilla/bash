#!/bin/sh -e
# Confluence startup script

#chkconfig: 2345 80 05
#description: Confluence

# ref http://confluence.atlassian.com/display/DOC/Start+Confluence+automatically+on+Linux+and+UNIX

### BEGIN INIT INFO
# Provides:          confluence
# Required-Start:    $local_fs $remote_fs $network $syslog
# Required-Stop:     $local_fs $remote_fs $network $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# X-Interactive:     true
# Short-Description: Start/stop Confluence standalone server
### END INIT INFO
 
# Define some variables
# Name of app ( JIRA, Confluence, etc )
APP=confluence
# Name of the user to run as
USER=confluence
# Location of application's bin directory
CATALINA_HOME=/usr/local/confluence
# Location of Java JDK
[ -e /usr/java/jdk/bin/java ] && export JAVA_HOME=/usr/java/jdk

ipaddr="$(ifconfig eth0 | grep "inet addr:" | awk '{print $2}' | cut -d: -f2)"
ipport="9980"
TESTURL="http://${ipaddr}:${ipport}"

setpslist() {
  PSLIST=$(ps a --width=1000 --User "$USER" -o  pid,user,command  | grep "$CATALINA_HOME/bin/bootstrap.jar" | grep -v PID | grep -v grep | awk '{printf $1 " "}')
}

case "$1" in
  # Start command
  start)
    echo "Starting $APP"
    /bin/su -m $USER -c "$CATALINA_HOME/bin/startup.sh &> /dev/null"
    ;;
  stop)
    echo "Stopping $APP"
    /bin/su -m $USER -c "$CATALINA_HOME/bin/shutdown.sh &> /dev/null"
    starttime=$(date +"%s")
    while true; do
      sleep 3
      now=$(date +"%s")
      setpslist
      if [ -z "$PSLIST" ]; then
        echo "$APP stopped successfully"
        exit 0
      fi
      if [ $(($now - 80)) -gt $starttime ]; then
        echo "$APP: Graceful shutdown taking too long, killing it.";
        kill -9 $PSLIST
      elif [ $(($now - 50)) -gt $starttime ]; then
        echo "$APP: Graceful shutdown taking too long, terminating it.";
        kill -15 $PSLIST
      fi
    done
    ;;
  status)
    setpslist
    if [ -z "$PSLIST" ]; then
      echo "$APP is not running"
      exit 0
    fi
    MSG="$APP ( PIDs $PSLIST) is running "
    if wget --tries=1 --timeout=1 --server-response -O - "$TESTURL" 2>&1 | grep -qai " HTTP/1.1 "; then
      echo "$MSG and listening on $TESTURL"
    else
      echo "$MSG but not responding on $TESTURL"
    fi
    ;;
  restart)
    $0 stop
    sleep 5
    $0 start
    ;;
  *)
    echo "Usage: /etc/init.d/$APP {start|restart|stop}"
    exit 1
    ;;
esac
 
exit 0
