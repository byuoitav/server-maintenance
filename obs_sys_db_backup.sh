#!/bin/bash
# Shell script to backup MySQL database for Observation Systems
# Cloned and based on Script from NARKOZ/db_backup.sh - https://gist.github.com/NARKOZ/642511

# directories to backup
# for each directory to be backed up you must add an output directory,

BDIR=/usr/local/valt/backup/db
LOGDIR=/usr/sbin/backups/logs

ELKADDR=http://avmetrics.byu.edu/backups/observation
########################################################################

# Load Environment Variables where DB Username and DB Password are located
source /root/.db_backupuser

# Set these variables
DBUSER="${DB_USERNAME}" # DB_USERNAME
DBPASS="${DB_PASSWORD}" # DB_PASSWORD
#MyHOST=""      # DB_HOSTNAME

# Backup Dest directory
DEST="${BDIR}" # /home/username/backups/DB

# Email for notifications
EMAIL="${BACKUP_EMAIL}"

# How many days old files must be to be removed
DAYS=7

# Linux bin paths
MYSQL="$(which mysql)"
MYSQLDUMP="$(which mysqldump)"
GZIP="$(which gzip)"

# Get date in dd-mm-yyyy format
NOW="$(date +"%Y-%m-%d_%T")"

# Archive the directory, send mail and cleanup
$MYSQLDUMP -u $DBUSER -p$DBPASS v3 | gzip -c > $DEST/v3_$NOW.sql.gz

# Remove old files
# find $DEST -mtime +$DAYS -exec rm -f {} \;
find $DEST -type f -mtime +7 -name '*.gz' -print0 | xargs -r0 rm --
