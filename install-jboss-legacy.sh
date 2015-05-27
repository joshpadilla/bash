#!/bin/bash

#
# install script for jboss
#

jboss_version="6.0.0.Final"
jboss_archive="jboss-as-distribution-${jboss_version}.zip"
#jboss_version="5.1.0.GA"
#jboss_archive="jboss-${jboss_version}.zip"

# some globals
export DEBIAN_FRONTEND="noninteractive"
WGET_OPTS="--tries=2 --timeout=10 --quiet"
FILE_SOURCE="http://downloads.rimuhosting.com"
INSTALL_TARGET="/usr/local/jboss"

# support + debugging defaults, managed via command line options
ERRORMSG=
export DEBIAN_FRONTEND="noninteractive"
CALLER=$(ps ax | grep "^ *$PPID" | awk '{print $NF}')
DEBUG=
DEBUG_LOG="/root/cms_install.log"

echo "
 $0 ($Id: installjboss-legacy.sh 216 2012-03-27 03:36:44Z juan $)
 Copyright Rimuhosting.com
"

installjboss() {
echo "* Installing JBoss version ${jboss_version} ..."

if [[ $(id -u) != "0" ]] ; then
  ERRORMSG="You should be root to run this (e.g. sudo $0 $* ) "
  return 1
fi

echo -n "  ...installing required tools and packages : "
required="unzip libaio1"
for package in $required; do
  apt-get -qq install $package  >> $DEBUG_LOG 2>&1;
  if [ $? -eq 0 ]; then
    echo -n "$package "
  fi
done
echo

if [ ! -e "$jboss_archive" ]; then
  echo "  ...downloading jboss"
  wget ${WGET_OPTS} ${FILE_SOURCE}/${jboss_archive}
  if [ $? -ne 0 ]; then
    ERRORMSG="failed downloading jboss"
    return 1
  fi
fi

# move existing jboss install out of the way
if [ -e ${INSTALL_TARGET} ]; then
  bkdate=`date +%Y%m%d-%s`
  echo "  ...moving old jboss installation to ${INSTALL_TARGET}-backup-$bkdate"
  mv ${INSTALL_TARGET} ${INSTALL_TARGET}-backup-$bkdate
fi

echo "  ...unzipping jboss"
unzip -qq "${jboss_archive}"
if [ $? -ne 0 ]; then
  ERRORMSG="problem unpacking jboss files"
  return 1
fi

echo "  ...moving files to the right place"
mv jboss-${jboss_version} ${INSTALL_TARGET}
if [ ! -d ${INSTALL_TARGET} ]; then
  ERRORMSG="problem updating jboss folder location"
  return 1
fi

echo -n "  ...installing setup tweaks: "
if [[ -d /etc/logrotate.d ]]; then
  echo -n "logrotate "
  wget ${WGET_OPTS} ${FILE_SOURCE}/jboss.logrotate
  mv jboss.logrotate /etc/logrotate.d/jboss.logrotate
  if [  $? -ne 0 ]; then
    ERRORMSG="failed retrieving logrotate script"
    return 1
  fi
fi
echo -n "initscript "
wget ${WGET_OPTS} ${FILE_SOURCE}/javainitscript
mv javainitscript /etc/init.d/jboss
if [  $? -ne 0 ]; then
  ERRORMSG="failed retrieving jboss init script"
  return 1
fi
chmod +x /etc/init.d/jboss
echo -n "run.conf "
wget ${WGET_OPTS} ${FILE_SOURCE}/jboss.conf
mv jboss.conf ${INSTALL_TARGET}/bin/run.conf
if [ $? -ne 0 ]; then
  ERRORMSG="failed retrieving jboss conf"
  return 1
fi
echo

echo "  ...installing mysql/j connector"
if [ ! -e  ${INSTALL_TARGET}/server/default/lib/mysql-connector.jar ]; then
  wget ${WGET_OPTS} ${FILE_SOURCE}/mysql-connector.jar
  if [ $? -ne 0 ]; then
    ERRORMSG="failed retreiving mysql/j connector package"
    return 1
  fi
  mv mysql-connector.jar ${INSTALL_TARGET}/server/default/lib
fi

echo "  ...creating a local tmp folder for jboss"
mkdir -p ${INSTALL_TARGET}/tmp

echo "  ...setting jboss to listen for local connections only"
cd ${INSTALL_TARGET}/server/default/deploy
sed -i 's/JBOSS_OPTIONS=""/JBOSS_OPTIONS="-b 127.0.0.1"/' ${INSTALL_TARGET}/bin/run.conf

echo "  ...reducing the copious number of threads that jboss creates"
SERVERXMLDIR=deploy/jbossweb.sar
for basedir in ${INSTALL_TARGET}/server/default/$SERVERXMLDIR ${INSTALL_TARGET}/server/all/$SERVERXMLDIR; do
    sed -i 's/minSpareThreads="25"/minSpareThreads="1"/' $basedir/server.xml
    sed -i 's/maxSpareThreads="75"/maxSpareThreads="2"/' $basedir/server.xml
    sed -i 's/maxSpareThreads="25"/maxSpareThreads="2"/' $basedir/server.xml
    sed -i 's/maxSpareThreads="15"/maxSpareThreads="2"/' $basedir/server.xml
    sed -i 's/tc qThreadCount="6"/tcpThreadCount="1"/' $basedir/server.xml
    sed -i 's/maxThreads="4"/maxThreads="2"/' $basedir/server.xml
    sed -i 's/minSpareThreads="2"/minSpareThreads="1"/' $basedir/server.xml
    sed -i 's/maxSpareThreads="4"/maxSpareThreads="2"/' $basedir/server.xml
done

echo -n "  ...disabling insecure extensions (moved to $INSTALL_TARGET/disabled): "
mkdir -p ${INSTALL_TARGET}/disabled
for extension in jmx-console.war web-console.war http-invoker.sar jmx-invoker-adaptor-server.sar; do
  jmxdirs=$(find /usr/local/jboss/server/ -maxdepth 4 -type d -name $extension) 
  for jmx in $jmxdirs; do 
    newdir=${INSTALL_TARGET}/disabled/$(echo $jmx | sed 's/\//_/g') 
    echo -n "$jmx "
    mv $jmx $newdir
  done
done

# fixes http://m.ri.mu/view.php?id=664
echo "  ...further securing jboss"
for propfile in ${INSTALL_TARGET}/server/*/conf/props/jmx-console-users.properties; do
  sed -i "s/admin=admin/admin=$(cat /dev/urandom | tr -cd "[:alnum:]" | head -c 16)/" "$propfile"
done
if [[ -e ${INSTALL_TARGET}/common/deploy/jmx-console.war/WEB-INF/jboss-web.xml ]]; then
  echo '<!DOCTYPE jboss-web PUBLIC
   "-//JBoss//DTD Web Application 5.0//EN"
   "http://www.jboss.org/j2ee/dtd/jboss-web_5_0.dtd">
   
<jboss-web>
      <security-domain>java:/jaas/jmx-console</security-domain>
</jboss-web>' > ${INSTALL_TARGET}/common/deploy/jmx-console.war/WEB-INF/jboss-web.xml
fi
sed -i -e "112d" ${INSTALL_TARGET}/common/deploy/jmx-console.war/WEB-INF/web.xml
sed -i 's/secured access to the HTML JMX console./secured access to the HTML JMX console.-->/' ${INSTALL_TARGET}/common/deploy/jmx-console.war/WEB-INF/web.xml


echo "  ...make sure 'jboss' user exists"
if ! grep -qai jboss /etc/passwd; then
  if [ -e /etc/debian_version ]; then
    adduser --shell /sbin/nologin --home ${INSTALL_TARGET} --system jboss
  else
    adduser -r -s /sbin/nologin jboss -d ${INSTALL_TARGET}
  fi
fi

echo "  ...fixing permissions on ${INSTALL_TARGET}"
chown -R jboss ${INSTALL_TARGET}

echo "  ...running additional system configuratiuon fixes to improve jboss stability"
sed -i "s|/var/jboss|${INSTALL_TARGET}|" /etc/passwd
sed -i "s|/etc/jboss.conf|${INSTALL_TARGET}/conf/jboss.conf|" /etc/init.d/jboss
 
echo
echo "The files are all under ${INSTALL_TARGET}. The config options are
in ${INSTALL_TARGET}/bin/run.conf. You can still stop and start jboss with
/etc/init.d/jboss. And jboss logs will be rotated based on
/etc/logrotate.d/jboss.logrotate.  You can have jboss start by default by
running 'chkconfig --level 35 jboss on' or 'update-rc.d jboss defaults'

For more jboss security things see the docs at 
http://docs.jboss.org/jbosssecurity/docs/6.0/security_guide/html/

${INSTALL_TARGET}/bin/run.conf JBOSS_OPTIONS is set to \'-b 127.0.0.1\'.
That way JBoss will only listen on the local network interface.  You can use
mod_proxy to direct web requests to JBoss.  This is just a bit of insurance in
case someone tries to do a direct connection to your JBoss services.

If you want to test things before using mod_proxy, you can SSH to your
server using 'ssh -L 8080:localhost:8080 yourserverip'.  This will create a
tunnel from your local machines port 8080 to your servers port 8080 (JBoss).
Then you can browse to http://localhost:8080 and the connection will be
redirected to your server."
}

installjboss
if [[ $? -ne 0 ]]; then
  echo
  echo "! Error from install: $ERRORMSG"
  echo
  exit 1
fi

