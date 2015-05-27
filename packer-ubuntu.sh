#Install packer for Ubuntu Server
#Link brittle/hard coded until repository created
wget https://dl.bintray.com/mitchellh/packer/0.7.2_linux_amd64.zip
mkdir /usr/local/packer

#Another hard coded ver number
unzip 0.7.2_linux_amd64.zip -d /usr/local/packer

#Symbolic link to /usr/local/bin
#Perhaps this helps with path finding?
ln -s /usr/local/packer/packer /usr/local/bin


cd packer-qemu/ubuntu
packer build ubuntu-14.04-server-amd64.json
