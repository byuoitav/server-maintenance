#!/bin/bash
# Script for restarting Wowza if Videos continue to run after hours.  
# Script will run every night at 1 am when no one will be using the system
# Script will look to see if Wowza has any files that are open at 1 am.  If it finds that a file is open, the script will restart Wowza and then check to see if Wowza is running. 
#
# Directory to send logs for the system

LOGDIR=/usr/sbin/backups/logs
LOGDATE = `date +%Y-%m-%d:%H:%M:%S` 

#Script Block
#####################################################################################################################

echo "-----------------------------------------------------------------------------" >> $LOGDIR/WowzaRestartScript_$LOGDATE.txt
echo "$LOGDATE" >> $LOGDIR/WowzaRestartScript_$LOGDATE.txt
echo ""  >> $LOGDIR/WowzaRestartScript_$LOGDATE.txt


wowzafiles='lsof | grep \/usr\/local\/Wowza.*\/content'
if [ "${wowzafiles}" != ""]; then
	
fi

sudo service WowzaStreamingEngine restart