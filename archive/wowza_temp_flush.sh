#!/bin/bash
# Shell script to remove files from a directory that are older than 7 days
# For this script, run it as the user that has access to the directory in question

# directory to watch and remove old files
#

#DTW=/usr/local/WowzaStreamingEngine/content/CTL/TRANSCODE/prd/webrtc_incoming
#DTW=/usr/local/WowzaStreamingEngine/content/CTL/TRANSCODE/stg/webrtc_incoming
DTW=/usr/local/WowzaStreamingEngine/content/CTL/TRANSCODE/dev/webrtc_incoming
LOGDIR=/home/wowza/logs

########################################################################

# Get date in dd-mm-yyyy format
NOW="$(date +"%Y-%m-%d_%T")"

FILENAME=$NOW"_webrtc_cleanup.txt"
LOGPATH="$LOGDIR/$FILENAME"

# Create log for today for files being removed:
touch $LOGDIR/$FILENAME

# How many days old files must be to be removed
DAYS=7

echo $NOW >> $LOGPATH
echo "The following files are going to be removed:" >> $LOGPATH

# Before removing the files, capture in logs which files are going to be removed
find $DTW -type f -mtime +$DAYS -name '*.mp4' >> $LOGPATH

# Remove old files
# find $DEST -mtime +$DAYS -exec rm -f {} \;
find $DTW -type f -mtime +$DAYS -name '*.mp4' -print0 | xargs -r0 rm -- 
