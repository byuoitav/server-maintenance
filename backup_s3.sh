#!/bin/bash

# Configure the following variables in the /etc/environment file 
# $BUCKETNAME
# $STORAGECLASS

source /etc/environment
source /root/.bash_aliases

# directories to backup
# for each directory to be backed up you must add an output directory
# These top ones will backup just the application and content folders
# use these only on Media servers and not on the main application server
#
#ODIR=($BUCKETNAME/$HOSTNAME/content)
#
#BDIR=(/usr/local/WowzaStreamingEngine/content)

# On the main cluster server: comment out the above lines and uncomment the following lines: 
# These lines contain the correct lines for backing up everything including the database backups:

ODIR=(
$BUCKETNAME/$HOSTNAME/content
$BUCKETNAME/$HOSTNAME/db)

BDIR=(
/usr/local/WowzaStreamingEngine/content
/usr/local/valt/backup/db)

LOGDIR=/usr/sbin/backups/logs

# Number of days to retain backups
RETDAYS=30

# TODOs - 
# Slack Integration
# System Checks
########################################################################


STIME=`date +%Y-%m-%dT%H:%M:%S%z`

# Check for stale file handle

if [ ! -d $LOGDIR ]
then
	mkdir $LOGDIR
fi

if [ ${#BDIR[@]} -ne ${#ODIR[@]} ];
then
	echo "local directories do not equal the backup directories in AWS"
        exit -1
fi	

# Verify AWS CLI Credentials are setup
# http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html
if ! grep -q aws_access_key_id ~/.aws/config; then
  if ! grep -q aws_access_key_id ~/.aws/credentials; then
    echo "AWS config not found or CLI not installed. Please run \"aws configure\"."
    exit 1
  fi
fi

BACKUPDIR=`date +%Y-%m-%d:%H:%M:%S`

export PATH=$PATH:/bin:/usr/bin:/usr/local/bin
VAR=0

# Backup files and Archive deleted files in incremental folder
for P in ${BDIR[@]}
do
	INCREMENTALDIR=${ODIR[$var]}/incremental/$BACKUPDIR
	OPTS="--sse --storage-class=$STORAGECLASS --delete --no-follow-symlink"

	#echo $P
	echo "Backups for $HOSTNAME started at $STIME" >> $LOGDIR/$BACKUPDIR.txt
        echo "" >> $LOGDIR/$BACKUPDIR.txt 
        echo ${ODIR[$var]}
	echo "-------------$P >> ${ODIR[$var]}--------------" >> $LOGDIR/$BACKUPDIR.txt
	echo "-------------Sending Backups to S3 using AWS SYNC----------------" >> $LOGDIR/$BACKUPDIR.txt
	echo "" >> $LOGDIR/$BACKUPDIR.txt

        # transfer
        aws s3 sync $P ${ODIR[$var]} $OPTS >> $LOGDIR/$BACKUPDIR.txt
        echo "" >> $LOGDIR/$BACKUPDIR.txt
	
	((var++))      	
done

curl -X POST -H 'Content-type: application/json' --silent --data "{'text':'Backup finished - $HOSTNAME. Please check backup logs for details....'}"  $SLACK_ADDR

FTIME=`date +%Y-%m-%dT%H:%M:%S%z`
echo "BACKUP COMPLETE - $FTIME"  >> $LOGDIR/$BACKUPDIR.txt

# curl -X POST -H --silent --data-urlencode "payload={\"text\": \"$(cat $LOGDIR/$BACKUPDIR.txt | sed "s/\"/'/g")\"}" $SLACK_ADDR
