#!/bin/bash

export PATH=$PATH:/bin:/usr/bin:/usr/local/bin

# Configure the following variables in the /etc/environment file 
source /etc/environment
source /root/.bash_aliases

STIME=`date +%Y-%m-%dT%H:%M:%S%z`

# Check for stale file handle
if [ ! -d $LOGDIR ]
then
	mkdir $LOGDIR
fi

# Get commandline options
while getopts 'p:' opt; do
	case "$opt" in
		p) 
		  arg="$STOREPATH"
		  echo "Processing path with the option '${STOREPATH}'"
		  ;;
		:)
		  echo -e "Option requires an arguement. \nUsage: $(basename $0) [-p arg]"
		  exit 1
		  ;;
		?) 
		  echo -e "Invalid command option.\nUsage: $(basename $0) [-p arg]"
		  exit 1
	esac
done

# Read the /proc/mounts directory for the mount path
MOUNTCHECK=$(grep '${STOREPATH}' /proc/mounts) 

# Evaluate the line from /proc/mounts
if [ -z "$STOREPATH" ]
then
	echo "${STOREPATH} is not mounted on this server"
else
	echo "${STOREPATH} is mounted, checking if it is in read only mode"
	if [[ "$STOREPATH" == *" ro "* ]]; then
		echo "${STOREPATH} is in Read Only Mode"
		echo "Sending alert to Teams"  
fi

# If the mount is ro in the line, try to write a file to 
# /usr/local/WowzaStreamingEngine/content/valt_recordings 
# If it returns with an error, check to see if the file is in directory
# If the file isn't there, post an alert into teams
#######################################################



# Post content to Teams using a webhook 
curl -X POST -H 'Content-type: application/json' --silent --data "{'text':'Backup finished - $HOSTNAME. Please check backup logs for details....'}"  $SLACK_ADDR

FTIME=`date +%Y-%m-%dT%H:%M:%S%z`
echo "Check Complete - $FTIME"  >> $LOGDIR/$BACKUPDIR.txt

# curl -X POST -H --silent --data-urlencode "payload={\"text\": \"$(cat $LOGDIR/$BACKUPDIR.txt | sed "s/\"/'/g")\"}" $SLACK_ADDR
