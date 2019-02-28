#!/bin/bash

# Script - Checks to see if Wowza Streaming Engine is running
# Current Server issue occurs on Ubuntu 14.04 and Wowza Streaming Engine 4.7 
# Service reports back that WowzaStreamingEngine process is stopped when the process is running.
# ps -ef | grep WowzaStreamingEngine returns that the process is running even when
# Service report back as stopped.
#
# Script will restart Wowza if the system check over port 1935 fails to return the proper response
# Script will then report back in local logs as well as over slack to a Slack app/channel
#

export PATH=$PATH:/bin:/usr/bin:/usr/local/bin 
source /etc/environment

HOSTNAME=`uname -n`

LOGDIR=/usr/sbin/maintenance/logs

LOGNAME=`date +%Y-%m-%d:%H:%M:%S` 

#Environment Variables --------------------------------
SLACK_ADDR=${SLACK_POST_ADDRESS}

DATE=`date +%Y-%m-%dT%H:%M:%S%z`

LOGNAME="wowza_restart_$DATE" 

##################################################################

send_message () {
	curl -X POST -H --silent --data-urlencode "payload={\"text\": \"$(cat $LOGDIR/$LOGNAME.txt | sed "s/\"/'/g")\"}" $SLACK_ADDR
}

# Make sure that the log path has already been created, if not create it
if [ ! -d $LOGDIR ]
then
	mkdir $LOGDIR
fi

SERVICETEST=`curl localhost:1935`

# If there are open tmp files on the system, restart Wowza and check that Wowza is active
# Currently on the servers, we can't check using standard service check because it is broken
# We are going to check using the Wowza HTTP API to make sure that the service is running 
if [[ $SERVICETEST != *"Wowza Streaming"* ]]; then
	touch $LOGDIR/$LOGNAME.txt
	echo "************************************************" >> $LOGDIR/$LOGNAME.txt
	echo "SERVER NAME: $HOSTNAME" >> $LOGDIR/$LOGNAME.txt
	echo "-----------------------------------------------" >> $LOGDIR/$LOGNAME.txt
	echo "Wowza Streaming Engine Check Script" >> $LOGDIR/$LOGNAME.txt
	echo "Run on: " >> $LOGDIR/$LOGNAME.txt 
	echo $DATE >> $LOGDIR/$LOGNAME.txt 
	echo "-----------------------------------------------" >> $LOGDIR/$LOGNAME.txt
	echo "" >> $LOGDIR/$LOGNAME.txt
	echo "Wowza Streaming Engine is currently not running" >> $LOGDIR/$LOGNAME.txt
	echo "Current Output:" >> $LOGDIR/$LOGNAME.txt
	echo $SERVICETEST >> $LOGDIR/$LOGNAME.txt
	echo "------------------------------------------" >> $LOGDIR/$LOGNAME.txt 
	echo "Rebooting WowzaStreamingEngine"  >> $LOGDIR/$LOGNAME.txt
	WOWZARESTART=`service WowzaStreamingEngine restart` 
	echo $WOWZARESTART >> $LOGDIR/$LOGNAME.txt 
	sleep 30
	# Checking using curl instead of checking using the service due to
	# an issue where Wowza Streaming Engine doesn't show the correct
	# state so this check is better
	SERVICETEST=`curl localhost:1935`
	if [[ $SERVICETEST == *"Wowza Streaming"* ]]; then
		echo $SERVICETEST >> $LOGDIR/$LOGNAME.txt
		echo "Wowza reboot was successful"  >> $LOGDIR/$LOGNAME.txt
		echo "************************************************" >> $LOGDIR/$LOGNAME.txt
		send_message
	else
		echo "Wowza reboot was unsuccessful"  >> $LOGDIR/$LOGNAME.txt
		echo "Attempting one more reboot of Wowza"  >> $LOGDIR/$LOGNAME.txt
		echo "--------------------------------------------" >> $LOGDIR/$LOGNAME.txt 
		WOWZARESTART=`service WowzaStreamingEngine restart`
		echo $WOWZARESTART >> $LOGDIR/$LOGNAME.txt 
		sleep 30
		echo "" >> $LOGDIR/$LOGNAME.txt 
		echo "Checking Wowza Service"  >> $LOGDIR/$LOGNAME.txt
		# Second check if Wowza didn't restart properly the first time
		SERVICETEST=`curl localhost:1935`
		if [[ $SERVICETEST == *"Wowza Streaming"* ]]; then
			echo "Wowza reboot was successful"  >> $LOGDIR/$LOGNAME.txt
			echo "************************************************" >> $LOGDIR/$LOGNAME.txt
			send_message
		else
			echo "Wowza reboot was unsuccessful"  >> $LOGDIR/$LOGNAME.txt
			echo "Please check on the server and the service"  >> $LOGDIR/$LOGNAME.txt
			echo "************************************************" >> $LOGDIR/$LOGNAME.txt
			send_message
		fi
	fi
fi
