#!/bin/bash

# Original Backup Script from Observation Systems
# Backups were sent to a local NFS Mount on server for backup 
# Script was depricated for a newer script that backups up server directories to S3
#
#
# directories to backup
# for each directory to be backed up you must add an output directory
# These top ones will backup just the application and content folders
# use these only on Media servers and not on the main application server
#
#ODIR=(
#/mnt/observe/backups/$HOSTNAME/content
#/mnt/observe/backups/$HOSTNAME/www)

#BDIR=(
#/usr/local/WowzaStreamingEngine/content
#/var/www/v3)

# On the main cluster server: comment out the above lines and uncomment the following lines: 
# These lines contain the correct lines for backing up everything including the database backups:

ODIR=(
/mnt/observe/backups/$HOSTNAME/content
/mnt/observe/backups/$HOSTNAME/www
/mnt/observe/backups/$HOSTNAME/db)

BDIR=(
/usr/local/WowzaStreamingEngine/content
/var/www/v3
/usr/local/valt/backup)

LOGDIR=/usr/sbin/backups/logs

# Number of days to retain backups
RETDAYS=90

ELKADDR=http://avmetrics.byu.edu/backups/observation
########################################################################


DATE=`date +%Y-%m-%dT%H:%M:%S%z`


curl -X POST -d '{"timestamp"':'"'$DATE'"','"hostname"':'"'$HOSTNAME'"','"event"':'"Starting Backup"}' $ELKADDR

# Check for mount state of /mnt/observe and mount if it is not currently mounted
mntresult=`df -h 2>&1 | grep -i "/mnt/observe"`
if [ "${mntresult}" = ""]; then
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

if [ ! -d $LOGDIR ]
then
	mkdir $LOGDIR
fi

if [ ${#BDIR[@]} -ne ${#ODIR[@]} ];
then
	exit -1
fi	

BACKUPDIR=`date +%Y-%m-%d:%H:%M:%S`

export PATH=$PATH:/bin:/usr/bin:/usr/local/bin
VAR=0

# Backup files and Archive deleted files in incremental folder
for P in ${BDIR[@]}
do
	INCREMENTALDIR=${ODIR[$var]}/incremental/$BACKUPDIR
	OPTS="--force --delete --backup --backup-dir=$INCREMENTALDIR -avz"

	#echo $P
	echo ${ODIR[$var]}
	echo "-------------$P >> ${ODIR[$var]}/current--------------" >> $LOGDIR/$BACKUPDIR.txt
	echo "-------------Inrementals >> $INCREMENTALDIR ----------------" >> $LOGDIR/$BACKUPDIR.txt
	echo "" >> $LOGDIR/$BACKUPDIR.txt

      	# transfer
      	rsync $OPTS $P ${ODIR[$var]}/current >> $LOGDIR/$BACKUPDIR.txt
	echo "" >> $LOGDIR/$BACKUPDIR.txt
	
	((var++))      	
done

# Cleaning up old backups
for R in ${ODIR[@]}
do
        INCREMENTALOUTDIR=$R/incremental
        OPTS="-maxdepth 1 -type d -mtime +$RETDAYS"

        #echo $R
        echo $INCREMENTALOUTDIR
        echo "-------------Checking $R---------------" >> $LOGDIR/$BACKUPDIR.txt
        echo "-------------Old Deprecated Incrementals >> $INCREMENTALOUTDIR--------------" >> $LOGDIR/$BACKUPDIR.txt
        echo "" >> $LOGDIR/$BACKUPDIR.txt

        # find all the incrementals that are older than the retention period
        REMOVE=( $(find $INCREMENTALOUTDIR $OPTS | sort) )
        for i in ${REMOVE[@]}; do
                echo "Removing $i" >> $LOGDIR/$BACKUPDIR.txt
                rm -rf $i
        done
        echo "" >> $LOGDIR/$BACKUPDIR.txt

        # Remove the folders and files older than the retension days

        ((var++))
done

DATE=`date +%Y-%m-%dT%H:%M:%S%z`

curl -X POST -d '{"timestamp"':'"'$DATE'"','"hostname"':'"'$HOSTNAME'"','"event"':'"Backup Completed."}' $ELKADDR

