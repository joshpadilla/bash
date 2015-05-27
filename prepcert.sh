#!/bin/bash

httpdconfdir=/etc/httpd/conf
[ -e /etc/apache2 ] && httpdconfdir=/etc/apache2

is_wildcard="n"
domainname=""
keyfile=""
certfile=""
csrfile=""
keyfile_2048=0
keyfile_exist=0
keyfile_heartbleed=0
certfile_2048=0
certfile_exist=0
root_user=1
fn=$(date +%d%m%Y-%H%M)
cacertfile="$httpdconfdir/ssl.crt/RapidSSL_CA_bundle.pem"

# Create the private key and certificate signing request directories
mkdir -p $httpdconfdir/ssl.key
mkdir -p $httpdconfdir/ssl.csr
mkdir -p $httpdconfdir/ssl.crt


function verify_keyfile_matches_certfile() {
  echo -n "Checking private key and certificate match... "
#  echo "  Private Key file: ${keyfile}"
#  echo "  Certificate file: ${certfile}"
  certmd5=$(openssl x509 -noout -modulus -in ${certfile} | openssl md5)
  keymd5=$(openssl rsa -noout -modulus -in ${keyfile}| openssl md5)
  if [ "${certmd5}" == "${keymd5}" ]; then
    echo "good, private-key and certificate match!"
  else 
    echo "failed"
    echo "                 WARNING!"
    echo "  SSL private-key and certifcate DO NOT match!"
  fi
}


function gencsr() {
  csrfile="$csrfile-$fn"
  echo "Generating Certificate Signing Request (CSR) file in $csrfile"
  echo
  openssl req -new -key "$keyfile" -out "$csrfile"
  # the 'common name' must match your actual domain name
  # Leave the challenge password blank (press Enter)
}


# called if a key exists and is not 2048bits, or if a key does not exist at all
function genkey() {
  echo "Creating new 2048 bit private key..."
  base_key="${httpdconfdir}/ssl.key/${domainname}.2048.key"

  # no keyfile, it must have a name
  [ ! -e "${keyfile}" ] && keyfile="${base_key}-${fn}"

  echo "  Generating ${keyfile}..."
  openssl genrsa -out ${keyfile} 2048
  keyfile_exist=1
  keyfile_2048=1
  chmod 0600 ${keyfile}

  # if the base key name is a link, update that to point to new key
  if [ -L "${base_key}" ]; then
    echo "  Updating a symlink to ${base_key} from ${keyfile}, in case an old key\
 is needed for some reasons and the apache config is not yet updated to use the\
 new key file ${keyfile}"
    ln -s ${keyfile} ${base_key}
  elif [ ! -e "${base_key}" ]; then
    echo "  Creating a symlink to ${base_key} from ${keyfile}"
    ln -s ${keyfile} ${base_key}
  fi

}


function verify_certfile_2048() {
  echo -e "Checking if ssl certificate has 2048 bit encryption...\n"
  echo
  #2048 bit is required
  cert_bitness=$(openssl x509 -noout -text -in $certfile|grep Public-Key|grep -c 2048)
  if [ $cert_bitness -eq 1 ]; then
    $certfile_2048=1
    echo "  Yes, existing certificate $certfile is 2048 bit"
    echo
  else
    $certfile_2048=0
    echo "  Existing certificate $certfile is NOT 2048 bit, we need to generate\
 a new 2048 ssl private key and a new 2048 self-signing certificate"
  fi
}


function check_certfile_exist() {
  echo "Checking if already using an existing ssl certificate from our standard\
 location ${httpdconfdir}/ssl.crt\n"
  if [ -e "$httpdconfdir/ssl.crt/$domainname.2048.crt" ]; then
    certfile_exist=1
    certfile="$httpdconfdir/ssl.crt/$domainname.2048.crt" 
    echo "  Yes, found an existing certificate file ${keyfile}"
  else
    certfile_exist=0
    echo "  No existing ${httpdconfdir}/ssl.crt/${domainname}.2048.crt found."
    echo
  fi
}


function verify_keyfile_2048() {
  echo -n "Checking if private key file has 2048 bit encryption... "
  key_bitness=$(openssl rsa -noout -text -in ${keyfile}|grep Private-Key|grep -c 2048)
  if [ ${key_bitness} -eq 1 ]; then
    keyfile_2048=1
    echo "yes"
  else
    keyfile_2048=0
    echo "no"
    echo "  Will generate a new 2048 bit private key"
  fi 
}


function check_keyfile_exist() {
  echo "Identifying private key file for ${domainname}"
  if [ -e "${httpdconfdir}/ssl.key/${domainname}.2048.key" ]; then
    keyfile_exist=1
    keyfile="${httpdconfdir}/ssl.key/${domainname}.2048.key" 
    echo "  Found an existing private key file ${keyfile}"
  elif [ -e "${httpdconfdir}/ssl.key/${domainname}.key" ]; then
    keyfile_exist=1
    keyfile="${httpdconfdir}/ssl.key/${domainname}.key"
    echo "  Found an existing private key file at ${keyfile}"
  else
    keyfile_exist=0
    echo "  No existing private key files found."
  fi
}

function check_keyfile_age() {
    echo "Checking if key was generated using a vulnerable version of openssl"
    if [ $keyfile_exist -eq 1 ]; then
        keyage=$(stat -c %Y $keyfile)
        if [ $keyage -lt 1396915200 ]; then
            keyfile_heartbleed=1
            echo "Key file ${keyfile} is older than 08-04-2014, generating new key"
        else
            keyfile_heartbleed=0
            echo "Key file ${keyfile} is new than 08-04-2014"
        fi
    else
        keyfile_heartbleed=0
    fi
}


# create a self signed certificate for now.  You will overwrite this
# certificate with the one your SSL provider issues you
function genselfcert() {
  new_certfile="${certfile}-${fn}"
  echo
  echo "Generating a new self-signed certificate ${new_certfile}"
  openssl req -x509 -days 365 -in "$csrfile" -key "$keyfile"  -out "$new_certfile"
  if [ ! -e "$certfile" ]; then
    echo "  creating a symlink to $certfile"
    echo "  from $new_certfile"
    echo "  in case apache is not using the new cert file"
    ln -s "${new_certfile}" "${certfile}"
  fi
  certfile="${new_certfile}"
  echo

  # Double check your input:
# openssl req -noout -text -in $httpdconfdir/ssl.csr/$domainname.2048.csr

  # save the conf settings for when we get the cert
  echo "
export domainname=$domainname
export httpdconfdir=$httpdconfdir
" > /root/sslorderdetails
}


function getrapisslca() {
  if [ ! -e $httpdconfdir/ssl.key/RapidSSL_CA_bundle.pem ]; then 
    wget -q -O - http://downloads.rimuhosting.com/RapidSSL_CA_bundle.pem >  $httpdconfdir/ssl.crt/RapidSSL_CA_bundle.pem
  fi
}

function get_domain() {
  echo
  echo "What is the domain name that you want the SSL certificate to cover. This will be used for the certificate *file* name."
  if [ "$is_wildcard" == "y" ]; then
    echo "Since you have asked for a wildcard certificate, type the base domain without * or wildcard. e.g. for *.domain.com enter domain.com."
  fi
  while true; do
    echo -n "Enter the certificate name : "
    read domainname
    [ -n "${domainname}" ] && break
  done
  if [ $is_wildcard == "y" ]; then
    domainname="wildcard.${domainname}"
  fi
  
# echo "Using ${domainname}"
  echo
  keyfile="${httpdconfdir}/ssl.key/${domainname}.2048.key"
  certfile="${httpdconfdir}/ssl.crt/${domainname}.2048.crt"
  csrfile="${httpdconfdir}/ssl.csr/${domainname}.2048.csr"
}


function is_root_user() {
  user=$(id -u)
  if [ "$user" -ne 0 ]; then
    root_user=1   
    echo "                ##### IMPORTANT NOTICE #####"
    echo "You need to run this script as root user or with root privilege"
    echo "for example using sudo with \"sudo bash ${0##*/}\""
    echo 
    echo "current user id is $user "
    echo
    echo "exiting..."
    exit 
  fi
}


function is_wildcard_yn() {
  while true; do
    echo -en "\nWill this be a wildcard SSL certificate? (y/n or Ctrl-C to exit) "
    read is_wildcard
    case "$is_wildcard" in
      y | n | Y | N )
        break
        ;;
    esac
  done
}


function prepcert() {
  is_root_user
  getrapisslca
  is_wildcard_yn
  get_domain
  check_keyfile_exist
  if [ $keyfile_exist -eq 1 ]; then
    verify_keyfile_2048
    check_keyfile_age  
    if [ $keyfile_heartbleed -eq 1 ] || [ ! $keyfile_2048 -eq 1 ]; then
        genkey
    fi
  else
    genkey
  fi

  if [ $keyfile_exist -eq 1 ] && [ $keyfile_2048 -eq 1 ]; then
    gencsr
    genselfcert
  fi
  verify_keyfile_matches_certfile

  cat ${csrfile}

  #for new certificates
  echo
  echo "You may need to add these lines to your SSL-enabled VirtualHost:"
  echo
  echo "---------------------------- START HERE --------------------------------"
  echo " SSLEngine On
 SSLCertificateFile $certfile
 SSLCertificateKeyFile $keyfile
 SSLCACertificateFile $cacertfile"
  echo "----------------------------- END HERE ---------------------------------"
  echo
}

prepcert
