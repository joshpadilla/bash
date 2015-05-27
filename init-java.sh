#!/bin/bash

#
# $Id: javainitscript 164 2011-06-24 06:04:55Z glenn $
#
# Startup script for Jakarta Tomcat, Lferay, JBoss, or potentially other java apps
#
# chkconfig: 345 94 16
# description: Jakarta Tomcat Java Servlet/JSP Container or JBoss
# this script can be called tomcat or jboss.  Depending on what you
# name the file it will start up either tomcat or jboss.
# to enable on bootup on redhat "chkconfig --level 35 tomcat on"
# to enable on bootup on debian "update-rc.d tomcat defaults" or the
# slightly longer (but better run levels) "update-rc.d tomcat start 91 2 3 4 5  . stop 20 0 1 6 ."
# Change the chkconfig/update-rc.d from tomcat to jboss if that is what you actually
# want to run

### BEGIN INIT INFO
# Provides:          javainitscript
# Required-Start:    $syslog $time
# Required-Stop:     $syslog $time
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Java services
# Description:       Java services (like tomcat, liferay, jboss, etc)
### END INIT INFO

if [ -e /etc/debian_version ]; then
    . /lib/lsb/init-functions
elif [ -e /etc/init.d/functions ] ; then
    . /etc/init.d/functions
fi

if ! type log_daemon_msg 2>&1 |grep -qai function ; then
# no lsb setup?  no problem.  we will add them in

log_use_fancy_output () {
    TPUT=/usr/bin/tput
    EXPR=/usr/bin/expr
    if [ -t 1 ] && [ "x$TERM" != "" ] && [ "x$TERM" != "xdumb" ] && [ -x $TPUT ] && [ -x $EXPR ] && $TPUT hpa 60 >/dev/null 2>&1 && $TPUT setaf 1 >/dev/null 2>&1; then
        [ -z $FANCYTTY ] && FANCYTTY=1 || true
    else
        FANCYTTY=0
    fi
    case "$FANCYTTY" in
        1|Y|yes|true)   true;;
        *)              false;;
    esac
}

log_success_msg () {
    if [ -n "${1:-}" ]; then
        log_begin_msg $@
    fi
    log_end_msg 0
}

log_failure_msg () {
    if [ -n "${1:-}" ]; then
        log_begin_msg $@
    fi
    log_end_msg 1 || true
}

log_warning_msg () {
    if [ -n "${1:-}" ]; then
        log_begin_msg $@
    fi
    log_end_msg 255 || true
}

#
# NON-LSB HELPER FUNCTIONS
#
# int get_lsb_header_val (char *scriptpathname, char *key)
get_lsb_header_val () {
        if [ ! -f "$1" ] || [ -z "${2:-}" ]; then
                return 1
        fi
        LSB_S="### BEGIN INIT INFO"
        LSB_E="### END INIT INFO"
        sed -n "/$LSB_S/,/$LSB_E/ s/# $2: \(.*\)/\1/p" $1
}

# int log_begin_message (char *message)
log_begin_msg () {
    if [ -z "${1:-}" ]; then
        return 1
    fi
    echo -n "$@"
}

# Sample usage:
# log_daemon_msg "Starting GNOME Login Manager" "gdm"
#
# On Debian, would output "Starting GNOME Login Manager: gdm"
# On Ubuntu, would output " * Starting GNOME Login Manager..."
#
# If the second argument is omitted, logging suitable for use with
# log_progress_msg() is used:
#
# log_daemon_msg "Starting remote filesystem services"
#
# On Debian, would output "Starting remote filesystem services:"
# On Ubuntu, would output " * Starting remote filesystem services..."

log_daemon_msg () {
    if [ -z "${1:-}" ]; then
        return 1
    fi
    log_daemon_msg_pre "$@"

    if [ -z "${2:-}" ]; then
        echo -n "$1:"
        return
    fi

    echo -n "$1: $2"
    log_daemon_msg_post "$@"
}

# #319739
#
# Per policy docs:
#
#     log_daemon_msg "Starting remote file system services"
#     log_progress_msg "nfsd"; start-stop-daemon --start --quiet nfsd
#     log_progress_msg "mountd"; start-stop-daemon --start --quiet mountd
#     log_progress_msg "ugidd"; start-stop-daemon --start --quiet ugidd
#     log_end_msg 0
#
# You could also do something fancy with log_end_msg here based on the
# return values of start-stop-daemon; this is left as an exercise for
# the reader...
#
# On Ubuntu, one would expect log_progress_msg to be a no-op.
log_progress_msg () {
    if [ -z "${1:-}" ]; then
        return 1
    fi
    echo -n " $@"
}


# int log_end_message (int exitstatus)
log_end_msg () {
    # If no arguments were passed, return
    if [ -z "${1:-}" ]; then
        return 1
    fi

    retval=$1

    log_end_msg_pre "$@"

    # Only do the fancy stuff if we have an appropriate terminal
    # and if /usr is already mounted
    if log_use_fancy_output; then
        RED=`$TPUT setaf 1`
        YELLOW=`$TPUT setaf 3`
        NORMAL=`$TPUT op`
    else
        RED=''
        YELLOW=''
        NORMAL=''
    fi

    if [ $1 -eq 0 ]; then
        echo "."
    elif [ $1 -eq 255 ]; then
        /bin/echo -e " ${YELLOW}(warning).${NORMAL}"
    else
        /bin/echo -e " ${RED}failed!${NORMAL}"
    fi
    log_end_msg_post "$@"
    return $retval
}

log_action_msg () {
    echo "$@."
}

log_action_begin_msg () {
    echo -n "$@..."
}

log_action_cont_msg () {
    echo -n "$@..."
}

log_action_end_msg () {
    log_action_end_msg_pre "$@"
    if [ -z "${2:-}" ]; then
        end="."
    else
        end=" ($2)."
    fi

    if [ $1 -eq 0 ]; then
        echo "done${end}"
    else
        if log_use_fancy_output; then
            RED=`$TPUT setaf 1`
            NORMAL=`$TPUT op`
            /bin/echo -e "${RED}failed${end}${NORMAL}"
        else
            echo "failed${end}"
        fi
    fi
    log_action_end_msg_post "$@"
}

# Hooks for /etc/lsb-base-logging.sh
log_daemon_msg_pre () { :; }
log_daemon_msg_post () { :; }
log_end_msg_pre () { :; }
log_end_msg_post () { :; }
log_action_end_msg_pre () { :; }
log_action_end_msg_post () { :; }

fi

# how long to wait for the app to startup before saying 'its probably up'
STARTWAITTIMES=45

# figure out what to do based on the name of this script
if echo $0 | grep -qai tomcat; then
HOMEDIR=/usr/local/tomcat
TOMCAT_USER=tomcat
APPNAME=Tomcat
elif echo $0 | grep -qai alfresco; then
HOMEDIR=/usr/local/alfresco/tomcat
TOMCAT_USER=alfresco
APPNAME=Alfresco
elif echo $0 | grep -qai jboss; then
HOMEDIR=/usr/local/jboss
TOMCAT_USER=jboss
APPNAME=JBoss
STARTWAITTIMES=60
elif echo $0 | grep -qai liferay; then
tomcatloc=$( ls /usr/local/liferay | grep tomcat )
HOMEDIR=/usr/local/liferay/$tomcatloc
TOMCAT_USER=liferay
APPNAME=Liferay
if [ -d /home/$TOMCAT_USER ]; then
#since liferay can put some stuff (e.g. lucene search indexes)
chown -R $TOMCAT_USER:$TOMCAT_USER /home/$TOMCAT_USER
fi
STARTWAITTIMES=120
else
log_failure_msg "Unknown startup script name $0"
exit 1
fi

# something so we can test if the app is fully started
TESTURL=http://127.0.0.1:8080/
if [ -e $HOMEDIR/initscript/testurl ]; then
TESTURL=$(cat $HOMEDIR/initscript/testurl)
fi

#Necessary environment variables
[ -e /usr/java/jdk/bin/java ] && export JAVA_HOME=/usr/java/jdk
#export LD_KERNEL_ASSUME="2.2.5"

# set application specific defaults
if [ "$APPNAME" = "Tomcat"  -o "$APPNAME" = "Liferay" -o "$APPNAME" = "Alfresco" ]; then
    export CATALINA_HOME=$HOMEDIR
    INITSCRIPT=$HOMEDIR/bin/catalina.sh
    RUNCOMMAND="export CATALINA_HOME=$CATALINA_HOME; $INITSCRIPT start"
    STOPCOMMAND="$INITSCRIPT stop"
    GREPSTRING="$(basename $HOMEDIR).*[o]rg.apache.catalina.startup.Bootstrap start"
    LOGFILE=$HOMEDIR/logs/catalina.out
elif [ "$APPNAME" = "JBoss" ]; then
    . /usr/local/jboss/bin/run.conf
    INITSCRIPT=$HOMEDIR/bin/run.sh
    if [ -z "$JBOSS_CONFIGURATION" ]; then
        JBOSS_CONFIGURATION=default
    fi
    RUNCOMMAND="bash $INITSCRIPT -c $JBOSS_CONFIGURATION $JBOSS_OPTIONS "
    STOPCOMMAND="bash $HOMEDIR/bin/shutdown.sh $JBOSS_SHUTDOWN_OPTIONS "
    GREPSTRING="[o]rg.jboss.Main"
    LOGFILE=$HOMEDIR/server/$JBOSS_CONFIGURATION/log/jbconsole.log
else
    log_failure_msg "Only JBoss and Tomcat are recognised.  Not $APPNAME"
    exit 1
fi

# makes it a bit easier to find if the process is running.  e.g. put a -Dsomeval=Y
# into the JAVA_OPTS for the program.  e.g. in catalina.sh or setenv.sh or run.conf
if [ -e $HOMEDIR/initscript/grepstring ]; then
GREPSTRING=$(cat $HOMEDIR/initscript/grepstring)
fi

# allow overriding of these variables without script changes via a conf file
if [ -e $HOMEDIR/initscript/initscript.conf ] ; then
    source $HOMEDIR/initscript/initscript.conf
fi

#if [ "$APPNAME" = "Liferay" ]; then
#    TOMCAT_VER_DIR=$(ls $HOMEDIR | grep tomcat)
#    if [ -d "$TOMCAT_VER_DIR/logs" ]; then
#        LOGFILE=$HOMEDIR/$TOMCAT_VER_DIR/logs/ltconsole.out
#    fi
#fi

#Check for init script
if [ ! -f $INITSCRIPT ]; then
    log_failure_msg "$APPNAME not available... (no  $INITSCRIPT)"
    exit 1
fi

if ! id "$TOMCAT_USER" >/dev/null; then
    log_failure_msg "$TOMCAT_USER is not a user.  Please create a user account first."
    exit 1
fi

setpslist() {
    PSLIST=$(ps a --width=1000 --User "$TOMCAT_USER" -o  pid,user,command  | grep "$GREPSTRING" | grep -v PID | awk '{printf $1 " "}')
}
start() {
    setpslist
    log_daemon_msg "Starting" "$APPNAME"
    if [ ! -z "$PSLIST" ]; then
        log_warning_msg "$APPNAME already running, can't start it"
        log_end_msg 1
        return 1
    fi
    if [ ! -e "$LOGFILE" -a ! -e "`dirname \"$LOGFILE\"`" ]; then
        #log_action_msg "mkdir -p $(dirname "$LOGFILE")"
        mkdir -p $(dirname "$LOGFILE")
    fi
    if [ -e "$LOGFILE" ]; then
        #log_action_msg "mv $LOGFILE $LOGFILE.old"
        mv $LOGFILE{,.old}
    fi

    chown -R $TOMCAT_USER $HOMEDIR
    chmod -R g+w $HOMEDIR
    exec su - -p --shell=/bin/sh $TOMCAT_USER -c "cd $(dirname $INITSCRIPT); $RUNCOMMAND >\"$LOGFILE\"" 2>&1 &
    local starttime=$(date +"%s")
    # wait a bit for the app to startup
    while true; do
        sleep 3
        local now=$(date +"%s")
        if wget --tries=1 --timeout=1 --server-response -O - $TESTURL 2>&1 | grep -qai " HTTP/1.1 "; then
          log_end_msg 0
          break
        fi
        # process not starting (cf. http response not happening)
        if [ $(($now - 15 )) -gt $starttime ]; then
            setpslist
            if [ -z "$PSLIST" ]; then
                log_failure_msg "Java process not starting.  Last few lines from the startup log follow:"
                log_failure_msg "$(tail -n 4 $LOGFILE)"
                log_end_msg 1
                return 1
            fi
        fi
        if [ $(($now - $STARTWAITTIMES)) -gt $starttime ]; then
            log_warning_msg "$APPNAME startup taking too long, not getting a response on $TESTURL, giving up"
            log_end_msg 0
            return 0
        fi
        log_progress_msg .
    done
}


killprocesses() {
    log_daemon_msg "Killing" "$APPNAME"
    setpslist
    if [ -z "$PSLIST" ]; then
        log_progress_msg "$APPNAME not running, no need to kill it"
        log_end_msg 0
	return
    fi
    kill -9 $PSLIST
    log_end_msg 0
}

stop() {
    log_daemon_msg "Stopping" "$APPNAME"
    setpslist
    if [ -z "$PSLIST" ]; then
        log_progress_msg "$APPNAME not running, no need to stop it"
        log_end_msg 0
    fi
    waslistening=N
    needtokill=N
    if wget --tries=1 --timeout=1 --server-response -O - $TESTURL 2>&1 | grep -qai " HTTP/1.1 "; then
       waslistening=Y
    fi

    suoutput=$(su - --shell=/bin/bash -p $TOMCAT_USER -c "$STOPCOMMAND" 2>&1)
    local starttime=$(date +"%s")

    # wait a while for the app to shutdown gracefully, else kill it
    while true; do
        sleep 3
        local now=$(date +"%s")
        setpslist
        if [ -z "$PSLIST" ]; then
            log_end_msg 0
            return 0
        fi
        if echo $suoutput | egrep -qai "(Refused|Address already in use)" ; then
            log_warning_msg "'stop' signal refused, killing $APPNAME."
            kill -SIGTERM $PSLIST
        elif [ $(($now - 80)) -gt $starttime ]; then
            log_warning_msg "Graceful shutdown taking too long, killing it.";
            kill -SIGKILL $PSLIST
        elif [ $(($now - 50)) -gt $starttime ]; then
            log_warning_msg "Graceful shutdown taking too long, terminating it.";
            kill -SIGTERM $PSLIST
        elif [ "$needtokill" = "Y" ]; then
            log_progress_msg "Killing. "
            kill -SIGKILL $PSLIST
        elif [ "$waslistening" = "Y" -a "$needtokill" = "N" ]; then
            if  ! wget --tries=1 --timeout=1 --server-response -O - $TESTURL 2>&1 | grep -qai " HTTP/1.1 " ; then
            log_progress_msg  "Stopped listening on http, but not shutting down fully. "
            needtokill=Y
            sleep 10
            fi
        fi
        # echo -n $(echo $PSLIST | wc -w) " "
    done
}

status() {
    setpslist
    if [ ! -z "$PSLIST" ]; then
        local MSG="$APPNAME ( PIDs $PSLIST ) is running."
        if wget --tries=1 --timeout=1 --server-response -O - $TESTURL 2>&1 | grep -qai " HTTP/1.1 "; then
            log_success_msg "$MSG  And listening on $TESTURL."
        else
            log_warning_msg "$MSG  But not responding on $TESTURL."
        fi
    else
        log_failure_msg "$APPNAME is not running"
    fi
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
        sleep 3
        start
        ;;
     kill)
        killprocesses
        ;;
     killstart)
        killprocesses
	start
        ;;
     status)
        status
        ;;
     *)
        echo "Usage: $0 {start|stop|restart|status|kill|killstart}"
     exit 1
esac
exit $?

