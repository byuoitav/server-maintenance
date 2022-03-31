#!/bin/bash

# Script used to resync two observation system servers.  
# This is helpful for syncing servers in prep for migration
# We used this to true up the new server with the old prior to final cutover
#
#
# directories to backup
# for each directory to be backed up you must add an output directory,
#ODIR=(
#/mnt/observe/backups/$HOSTNAME/content
#/mnt/observe/backups/$HOSTNAME/www)

#BDIR=(
#/usr/local/WowzaStreamingEngine/content
#/var/www/v3)

#/usr/local/WowzaStreamingEngine/content/valt_recordings/video
# On the main cluster server: comment out the above lines and uncomment the following lines: 
#/usr/local/WowzaStreamingEngine/content/valt_recordings/video

BDIR=(
/usr/sbin/backups
/usr/local/WowzaStreamingEngine/content/valt_recordings/video
)


LOGDIR=/usr/sbin/backups/logs

# Number of days to retain backups
RETDAYS=90

ELKADDR=http://avmetrics.byu.edu/backups/observation

SERVER="compobserve1.byu.edu"
USER="ivsbackup"
OPTS="-avz -e \"ssh\" --rsync-path=\"sudo rsync\""

########################################################################

DATE=`date +%Y-%m-%dT%H:%M:%S%z`
: <<'END'
# Check for mount state of /mnt/observe and mount if it is not currently mounted
mntresult=`df -h 2>&1 | grep -i "/mnt/observe"`
if [ "${mntresult}" = "" ]; then
	mount -t nfs files.byu.edu:ObservationSystems /mnt/observe

	#check to see if /mnt/observe is now mounted and ready to use
	mntresult=`df -h 2>&1 | grep -i "/mnt/observe"`

	#if /mnt/observe still isn't mounted - report an error
	if ["${mntresult}" = ""]; then
		#Report to ELKi

                 DATE=`date +%Y-%m-%dT%H:%M:%S%z`

                 curl -X POST -d '{"timestamp"':'"'$DATE'"','"hostname"':'"'$HOSTNAME'"','"event"':'"Failed to Mount NFS Share for Backup Please check /mnt/observe"}' $ELKADDR
                 exit -1

	fi
fi

# Check for stale file handle
statresult=`stat /mnt/observe 2>&1 | grep -i "stale"`
if [ "${statresult}" != "" ]; then
	umount -f /mnt/observe
	mount -t nfs files.byu.edu:ObservationSystems /mnt/observe

	#check for stale mount again - if it's still bad, report an error. 
	statresult=`stat /mnt/observe 2>&1 | grep -i "stale"`

	if [ "${statresult}" != "" ]; then
		#Report to ELKi

		DATE=`date +%Y-%m-%dT%H:%M:%S%z`

		curl -X POST -d '{"timestamp"':'"'$DATE'"','"hostname"':'"'$HOSTNAME'"','"event"':'"Stale File Handle"}' $ELKADDR
		exit -1
	fi
fi
END
if [ ! -d $LOGDIR ]
then
	mkdir $LOGDIR
fi

BACKUPDIR="${DATE}_sync_servers"

export PATH=$PATH:/bin:/usr/bin:/usr/local/bin
VAR=0

#for B in ${BDIR[@]}
#for i in {1..${STOP}} 
#for (( i=$START; i<=$STOP; i++ )) 
for B in ${BDIR[@]}
do
	#INCREMENTALDIR=$ODIR/incremental/$BACKUPDIR/$i
	#OPTS="--force --delete --backup --backup-dir=$INCREMENTALDIR -avz"

	#echo $BDIR
	if [ -d $B ]; then
	  echo "Backing Up $B to $SERVER"
	  echo "-------------$B >> $SERVER@$B--------------" >> $LOGDIR/$BACKUPDIR.txt
	  echo "" >> $LOGDIR/$BACKUPDIR.txt

      	# transfer files from main directory to backup directory
      	  rsync -avz --delete -e "ssh" --rsync-path="sudo rsync" $B/ $USER@$SERVER:$B >> $LOGDIR/$BACKUPDIR.txt
	  echo "" >> $LOGDIR/$BACKUPDIR.txt
	else 
	  echo "" >> $LOGDIR/$BACKUPDIR.txt
	  echo "$BDIR does not exist, skipping directory" >> $LOGDIR/$BACKUPDIR.txt
	  echo "" >> $LOGDIR/$BACKUPDIR.txt
	fi

done

