#!/bin/bash

# Configure the following variables in the /etc/environment file 

source /etc/environment
source /root/.bash_aliases

# Get commandline options
while getopts 'p:' opt; do


# Read the /proc/mounts directory for the mount path
grep 

# Evaluate the line from /proc/mounts
# If the mount is ro in the line, try to write a file to 
# /usr/local/WowzaStreamingEngine/content/valt_recordings 
# If it returns with an error, check to see if the file is in directory
# If the file isn't there, post an alert into teams
#######################################################

STIME=`date +%Y-%m-%dT%H:%M:%S%z`

# Check for stale file handle
if [ ! -d $LOGDIR ]
then
	mkdir $LOGDIR
fi

export PATH=$PATH:/bin:/usr/bin:/usr/local/bin

# Post content to Teams using a webhook 
curl -X POST -H 'Content-type: application/json' --silent --data "{'text':'Backup finished - $HOSTNAME. Please check backup logs for details....'}"  $SLACK_ADDR

FTIME=`date +%Y-%m-%dT%H:%M:%S%z`
echo "BACKUP COMPLETE - $FTIME"  >> $LOGDIR/$BACKUPDIR.txt

# curl -X POST -H --silent --data-urlencode "payload={\"text\": \"$(cat $LOGDIR/$BACKUPDIR.txt | sed "s/\"/'/g")\"}" $SLACK_ADDR
