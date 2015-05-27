#!/bin/bash
#AWS Glacier Install & Data Upload Script

apt-get install python-setuptools git
git clone git://github.com/uskudnik/amazon-glacier-cmd-interface.git
../amazon-glacier-cmd-interface
python setup.py install

#Create glacier config file
touch .glacier-cmd

#Details of .glacier-cmd config file
[aws]
access_key=your_access_key
secret_key=your_secret_key

[glacier]
region=your_aws_region
logfile=~/.glacier-cmd.log
loglevel=INFO
output=print

#Create glacier vault
glacier-cmd mkvault "vaultName"

#Glacier upload commands
glacier-cmd upload --description "testFile1.txt" uploaded "testFile2.txt"

#Glacier looping upload routine
find . name "*.zip" | sort | while read file ; do
    echo "Uploading $(basename "$file") to Amazon Glacier."
    glacier-cmd upload --description "$(basename "$file")" photos "$file" && mv "$file" "uploaded"
done
