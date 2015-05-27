#!/bin/bash

dest=/backup/demo/`date +%A`

mkdir -p $dest

rsync -e 'ssh -p 30000' -avl --delete --stats --progress demo@123.45.67.890:/home/demo $dest/

#Use Crontab Command 'crontab -e'
#Cron runs rsync at 23.55hrs every day
55 23 * * *     sh /home/backup/bin/backup
