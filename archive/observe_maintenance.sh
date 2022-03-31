#!/bin/bash

# Script - Checks to see if Wowza is writing files after hours
# This will restart Wowza Streaming Engine if it finds files open 
# Set this up with Cron to function after hours with root user access
#
# Will close files that currently open by Wowza(Java) in the Wowza Path


export PATH=$PATH:/bin:/usr/bin:/usr/local/bin 
source /root/.db_backupuser
source /etc/environment

HOSTNAME=`uname -n`

LOGDIR=/usr/sbin/maintenance/logs

LOGNAME=`date +%Y-%m-%d:%H:%M:%S` 

ODIR='\/usr\/local\/Wowza.*\/content\/valt_recordings\/video\/.*\/*.tmp'

USER="${ADMIN_USER}"
DBUSER="${DB_USERNAME}" # DB_USERNAME
DBPASS="${DB_PASSWORD}" # DB_PASSWORD
DATABASE="v3"
DBSERVER="${DB_SERVER}" # DB_HOSTNAME

#Environment Variables --------------------------------
SLACK_ADDR=${SLACK_POST_ADDRESS}

DATE=`date +%Y-%m-%dT%H:%M:%S%z`
##################################################################

send_message () {
	curl -X POST -H --silent --data-urlencode "payload={\"text\": \"$(cat $LOGDIR/$LOGNAME.txt | sed "s/\"/'/g")\"}" $SLACK_ADDR
}

# Make sure that the log path has already been created, if not create it
if [ ! -d $LOGDIR ]
then
	mkdir $LOGDIR
fi

# Check to see if tmp files are open on the server in the Wowza content path
WOWZAOPEN=`lsof -nP | grep $ODIR`

# Check to see if there are any current recordings running
if [[ $HOSTNAME == $DBSERVER ]]; then
	SQLQUERY=`mysql -u$DBUSER -p$DBPASS -D $DATABASE -e "SELECT * FROM recordings"`
else 
	SQLQUERY=`ssh $USER@$DBSERVER.byu.edu "mysql -u$DBUSER -p$DBPASS -D $DATABASE -e 'SELECT * FROM recordings'"`
fi

touch $LOGDIR/$LOGNAME.txt
echo "************************************************" >> $LOGDIR/$LOGNAME.txt
echo "SERVER NAME: $HOSTNAME" >> $LOGDIR/$LOGNAME.txt
echo "-----------------------------------------------" >> $LOGDIR/$LOGNAME.txt
echo "Observation System Maintenance Script" >> $LOGDIR/$LOGNAME.txt
echo "Run on: " >> $LOGDIR/$LOGNAME.txt 
echo $DATE >> $LOGDIR/$LOGNAME.txt 
echo "-----------------------------------------------" >> $LOGDIR/$LOGNAME.txt
echo "" >> $LOGDIR/$LOGNAME.txt

echo "Current Open Recordings:" >> $LOGDIR/$LOGNAME.txt
if [[ ${WOWZAOPEN[@]} != "" ]]; then
	for OUTPUT in "${WOWZAOPEN[@]}" 
		do	
			echo -e "$OUTPUT\n" >> /tmp/output.txt
		done

	cat /tmp/output.txt | awk '{ print $10 }' | sort -u > /tmp/final_list.txt
	cat /tmp/final_list.txt >> $LOGDIR/$LOGNAME.txt
else 
	echo "No Current Recordings......." >> $LOGDIR/$LOGNAME.txt
fi

# Check to see if recordings are running, if they are, exit as that will give a false positive
if [[ ${SQLQUERY} != "" ]]; then
	echo "" >> $LOGDIR/$LOGNAME.txt
	echo "VALT managed recordings in progress:" >> $LOGDIR/$LOGNAME.txt
	echo $SQLQUERY >> $LOGDIR/$LOGNAME.txt
	echo "" >> $LOGDIR/$LOGNAME.txt
	echo "Recordings are still running on server"   >> $LOGDIR/$LOGNAME.txt                                                                                                                                     
	echo "Will not continue - Valt currently has recordings in progress"  >> $LOGDIR/$LOGNAME.txt
	echo "************************************************" >> $LOGDIR/$LOGNAME.txt
	send_message
	exit 1
fi       

# If there are open tmp files on the system, restart Wowza and check that Wowza is active
# Currently on the servers, we can't check using standard service check because it is broken
# We are going to check using the Wowza HTTP API to make sure that the service is running 
if [[ (${WOWZAOPEN} != "") && (${WOWZAOPEN} == *"java"*) ]]; then
	echo "There are tmp files open....."  >> $LOGDIR/$LOGNAME.txt
	echo "Checking to see they are open by Wowza"  >> $LOGDIR/$LOGNAME.txt
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
else
	echo "" >> $LOGDIR/$LOGNAME.txt
	echo "No current tmp files are open by Wowza"  >> $LOGDIR/$LOGNAME.txt
	echo "************************************************" >> $LOGDIR/$LOGNAME.txt
	echo "" >> $LOGDIR/$LOGNAME.txt
fi
