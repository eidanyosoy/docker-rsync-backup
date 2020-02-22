#!/bin/sh

#########################################################
# Script to do incremental rsync backups
# Adapted from script found on the rsync.samba.org
# Brian Hone 3/24/2002
# Updated 2015-10-09 by Johan Swetzén
# Adapted for Docker 2017-11-14 by Johan Swetzén
# This script is freely distributed under the GPL
#########################################################

# CRON_TIME (default: "0 1 * * *")
# - Time of day to do backup
# - Specified in UTC

#########################################
# From here on out, you probably don't  #
#   want to change anything unless you  #
#   know what you're doing.             #
#########################################
PIDFILE=/var/run/backup.pid
LOGS=/log

# Options to pass to rsync
OPTIONS="--force --ignore-errors --delete \
 --exclude-from=/root/backup_excludes \
 -avzhe --numeric-ids"

OPTIONSTAR="--warning=no-file-changed \
  --ignore-failed-read \
  --absolute-names \
  --warning=no-file-removed \
  --exclude-from=/root/backup_excludes
  --use-compress-program=pigz"

OPTIONSRCLONE="--config /rclone/rclone.conf \
 -v --size-only --stats-one-line --stats 1s --progress --tpslimit=10 \
 --checkers=8 --transfers=4 --no-traverse --fast-list"

INCREMENT=$(date +%Y-%m-%d)

# Make sure our backup tree exists
if [ -d "${ARCHIVEROOT}" ]; then
  rm -rf "${ARCHIVEROOT}" >/dev/null 2>&1
  install -d "${ARCHIVEROOT}"
  echo "Installed ${ARCHIVEROOT}"
  chmod -R 777 "${ARCHIVEROOT}"
else 
  install -d "${ARCHIVEROOT}"
  echo "Installed ${ARCHIVEROOT}"
  chmod -R 777 "${ARCHIVEROOT}"
fi

# Make sure Log folder exist 
  if [ -d "${LOGS}" ]; then
   install -d "${LOGS}"
   echo "$(date) : $LOGS exist - done"
  else 
    echo "$(date) : $LOGS not exist - create runs"
    install -d "${LOGS}"
    echo "$(date) : Installed $LOGS - done"
  fi

rsync_log()
{
tail -n 2 ${LOGS}/rsync.log
}

# Our actual rsyncing function
do_rsync()
{
 # shellcheck disable=SC2086
 # shellcheck disable=SC2164
  rsync ${OPTIONS} -e "ssh -Tx -c aes128-gcm@openssh.com -o Compression=no -i ${SSH_IDENTITY_FILE} -p${SSH_PORT}" "${BACKUPDIR}/" "$ARCHIVEROOT" >> ${LOGS}/rsync.log
}

tar_gz()
{
 # shellcheck disable=SC2086
 # shellcheck disable=SC2164
 # shellcheck disable=SC2006
cd ${ARCHIVEROOT}
 for dir_tar in `find . -maxdepth 1 -type d  | grep -v "^\.$" `; do
    echo "$(date) : Tar Backup running for ${dir_tar}"
    tar ${OPTIONSTAR} -C ${dir_tar} -cf ${dir_tar}.tar ./ >> ${LOGS}/tar.log
    echo "$(date) : Tar Backup of ${dir_tar} successfull"
 done
}

upload_tar()
{
# shellcheck disable=SC2164
# shellcheck disable=SC2086
# shellcheck disable=SC2164
if grep -q gcrypt /rclone/rclone.conf; then
  REMOTE="gcrypt"
 else
  REMOTE="gdrive"
fi
sid="/rclone/server.id"
if [ -f $sid ]; then
  echo "$(date) : ServerID Set to $(cat /rclone/server.id)"
else
  echo backup >/rclone/server.id
  echo "$(date) : NO ServerID Found"
fi
tree -a -L 1 ${ARCHIVEROOT} | awk '{print $2}' | tail -n +2 | head -n -2 | grep ".tar" >/tmp/tar_folders
p="/tmp/tar_folders"

while read p; do
  echo $p >/tmp/tar
  tar=$(cat /tmp/tar)
  rclone copyto ${ARCHIVEROOT}/${tar} ${REMOTE}:/backup/$(cat /rclone/server.id)/${tar} ${OPTIONSRCLONE}
  rclone copyto ${ARCHIVEROOT}/${tar} ${REMOTE}:/backup-daily/$(cat /rclone/server.id)/${INCREMENT}/${tar} ${OPTIONSRCLONE}
done </tmp/tar_folders
}

upload_tar_part2()
{
rrc="/rclone/rclone.conf"
if [ -f $rrc ]; then
  upload_tar
  echo "$(date) : Upload Backup done"
  remove_old_backups
  echo "$(date) : Purge Old Backups done"  
else
  echo "$(date) : NO rclone.conf Found"
  echo "$(date) : Backups not Uploaded"
  echo "$(date) : Backups are overwritted"
fi
}

remove_old_backups()
{
OPT="--config /rclone/rclone.conf"
rclone lsf ${REMOTE}:/backup-daily/$(cat /rclone/server.id)/ ${OPT} | head -n -14 >/tmp/backup_old
p="/tmp/backup_old"

while read p; do
  echo $p >/tmp/old_backups
  old_backup=$(cat /tmp/old_backups)
  rclone delete ${REMOTE}:/backup-daily/$(cat /rclone/server.id)/${old_backup} ${OPT}
done </tmp/backup_old
}

##EXECUTED PART
# Some error handling and/or run our backup and tar_create/tar_upload
if [ -f $PIDFILE ]; then
  echo "$(date): Backup already running, remove PID file to rerun"
  exit
else
  touch $PIDFILE;
  # Now the actual transfer
  do_rsync
  echo "$(date) : Rsync Backup done"
  echo "$(rsync_log)"
  tar_gz
  echo "$(date) : Tar Backup done"
  upload_tar_part2
  rm $PIDFILE;
fi

exit 0
