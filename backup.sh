#!/bin/sh

#########################################################
# Script to do rsync backups
# Adapted from script found on the rsync.samba.org
# Brian Hone 3/24/2002
# Updated 2015-10-09 by Johan Swetzén
# Adapted for Docker 2017-11-14 by Johan Swetzén
# This script is freely distributed under the GPL
#########################################################

# CRON_TIME (default: "0 1 * * *")
# - Time of day to do backup
# - Specified in Timezone

#########################################
# From here on out, you probably don't  #
#   want to change anything unless you  #
#   know what you're doing.             #
#########################################
PIDFILE=/var/run/backup.pid
LOGS=/log
RCCONFIG=/rclone/rclone.conf
INCREMENT=$(date +%Y-%m-%d)
RUNNER_COMMAND="--config /rclone/rclone.conf | tail -n 1 | awk '{print $2}'"
# Options to pass to rsync
OPTIONS="--force --ignore-errors --delete \
 --exclude-from=/root/backup_excludes \
 -avzheP --numeric-ids --ignore-times \
 --compress-level=${RSYNC_COMPRESS_LEVEL}"

OPTIONSTAR="--warning=no-file-changed \
  --ignore-failed-read \
  --absolute-names \
  --warning=no-file-removed \
  --exclude-from=/root/backup_excludes \
  --use-compress-program=pigz"

OPTIONSRCLONE="--config /rclone/rclone.conf \
  --checkers=4 --transfers=2 \
  --no-traverse --fast-list \
  --log-file=${LOGS}/rclone.log \
  --log-level=INFO --stats=30s \
  --stats-file-name-length=0 \
  --tpslimit=10 --tpslimit-burst=10 \
  --drive-chunk-size=128M  \
  --drive-acknowledge-abuse=true \
  --drive-stop-on-upload-limit \
  --bwlimit=20M --use-mmap"

OPTIONSREMOVE="--config /rclone/rclone.conf \
  --checkers=4 --no-traverse --fast-list \
  --log-file=${LOGS}/rclone-remove.log \
  --log-level=INFO --stats=30s \
  --stats-file-name-length=0 \
  --tpslimit=10 --tpslimit-burst=10 \
  --drive-chunk-size=128M  \
  --drive-acknowledge-abuse=true \
  --use-mmap"

OPTIONSTCHECK="--config /rclone/rclone.conf"

output="[Backup] `date '+%A %d-%B, %Y'`"

DISCORD="${LOGS}/discord.discord"
DISCORD_WEBHOOK_URL=${DISCORD_WEBHOOK_URL}
DISCORD_ICON_OVERRIDE=${DISCORD_ICON_OVERRIDE}
DISCORD_NAME_OVERRIDE=${DISCORD_NAME_OVERRIDE}

####### FUNCTIONS START #######
if [ ${DISCORD_WEBHOOK_URL} != 'null' ]; then
	# Make sure our backup tree exists
	if [ -d "${ARCHIVEROOT}" && -d "${LOGS}" ]; then
	  rm -rf ${DISCORD} 
	  echo "${output}"
	  echo "${output} : rsync docker started" >> "${DISCORD}"
	  install -d "${ARCHIVEROOT}" 
	  echo "${output} : Installed ${ARCHIVEROOT}"
	  chmod 777 "${ARCHIVEROOT}"
	  echo "Permission set for ${ARCHIVEROOT} || passed"
	  echo "${output} : ${LOGS}"
	  echo "${output} : LOGS exist - done"
	  chmod 777 "${LOGS}"
	  echo "${output} : rsync docker started"
	fi
  else
	  echo "rsync docker started"
	  echo "${output}"
	  install -d "${ARCHIVEROOT}"
	  echo "Installed ${ARCHIVEROOT}"
	  chmod 777 "${ARCHIVEROOT}"
	  echo "Permission set for ${ARCHIVEROOT} || passed"
	  echo "$LOGS not exist - create runs"
	  install -d "${LOGS}"
	  echo "Installed $LOGS - done"
	  chmod 777 "${LOGS}"
	  echo "${output} rsync docker started"
fi
# Send start message via Díscord 
if [ ${DISCORD_WEBHOOK_URL} != 'null' ]; then
   message=$(cat "${DISCORD}")
   msg_content=\"$message\"
   USERNAME=\"${DISCORD_NAME_OVERRIDE}\"
   IMAGE=\"${DISCORD_ICON_OVERRIDE}\"
   DISCORD_WEBHOOK_URL="${DISCORD_WEBHOOK_URL}"
   curl -H "Content-Type: application/json" -X POST -d "{\"username\": $USERNAME, \"avatar_url\": $IMAGE, \"content\": $msg_content}" $DISCORD_WEBHOOK_URL
 else
   echo "${output} rsync docker started"
fi
# Make sure rclone.conf exist 
if [ -f $RCCONFIG ]; then
  echo "${output} : rclone config found | files will stored on your Google drive"
  sleep 15
  # shellcheck disable=SC2164
  # shellcheck disable=SC2086
  # shellcheck disable=SC2164
  if grep -q gcrypt /rclone/rclone.conf; then
    REMOTE="gcrypt"
  else
    REMOTE="gdrive"
  fi
  if [ $(rclone lsd ${REMOTE}:/backup-daily/${SERVER_ID} ${OPTIONSTCHECK} | tail -n 1 | awk '{print $2}') == ${INCREMENT} ]; then
    echo "${output} : Backup already uploaded / finished" 
	echo "${output} : Next startup @ ${CRON_TIME}" 
    rm -rf $PIDFILE
    exit 0
  else
    echo "${output} :  Backup not exist || Backup starting"
  fi
else
  echo "${output} : WARNING = no rclone.conf found"
  echo "${output} : WARNING = Backups not uploaded to any place"
  echo "${output} : WARNING = backups are always overwritten"
  sleep 30
fi
remove_logs()
{
if [ -d ${LOGS} ]; then
   truncate -s 0 ${LOGS}/*.log
fi
}
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
 for dir_tar in `find . -maxdepth 1 -type d | grep -v "^\.$" `; do
    echo "${output} : Tar Backup running for ${dir_tar}"
    tar ${OPTIONSTAR} -C ${dir_tar} -cvf ${dir_tar}.tar ./ >> ${LOGS}/tar.log
    echo "${output} : Tar Backup of ${dir_tar} successfull"
 done
}
### left over remove before upload 
remove_folder()
{
# shellcheck disable=SC2086
# shellcheck disable=SC2164
# shellcheck disable=SC2006
cd ${ARCHIVEROOT}
 for dirrm in `find . -maxdepth 1 -type d | grep -v "^\.$" `; do
    echo "${output} : Remove folder running for ${dirrm}"
    rm -rf ${dirrm} >> ${LOGS}/removefolder.log
    echo "${output} : Remove folder of ${dirrm} successfull"
 done
}

### left over remove after upload
remove_tar()
{
# shellcheck disable=SC2086
# shellcheck disable=SC2164
# shellcheck disable=SC2006
cd ${ARCHIVEROOT}
 for tarrm in `find . -maxdepth 1 -type f | grep ".tar" `; do
    echo "${output} : Remove running for ${tarrm}"
    rm -rf ${tarrm} >> ${LOGS}/removetar.log
    echo "${output} : Remove of ${tarrm} successfull"
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

echo "${output} : Server ID set to ${SERVER_ID}"
tree -a -L 1 ${ARCHIVEROOT} | awk '{print $2}' | tail -n +2 | head -n -2 | grep ".tar" >/tmp/tar_folders
p="/tmp/tar_folders"
while read p; do
  echo $p >/tmp/tar
  tar=$(cat /tmp/tar)
  rclone copyto ${ARCHIVEROOT}/${tar} ${REMOTE}:/backup/${SERVER_ID}/${tar} ${OPTIONSRCLONE}
  rclone copyto ${ARCHIVEROOT}/${tar} ${REMOTE}:/backup-daily/${SERVER_ID}/${INCREMENT}/${tar} ${OPTIONSRCLONE}
done </tmp/tar_folders
}

remove_old_backups()
{
# shellcheck disable=SC2164
# shellcheck disable=SC2086
# shellcheck disable=SC2164
if grep -q gcrypt /rclone/rclone.conf; then
  REMOTE="gcrypt"
 else
  REMOTE="gdrive"
fi
if [ $(rclone lsd ${REMOTE}:/backup-daily/${SERVER_ID} ${OPTIONSTCHECK} | wc -l) -lt ${BACKUP_HOLD} ]; then
    echo "${output} : Daily Backups on ${REMOTE} lower as ${BACKUP_HOLD} set"
else
    rclone lsd ${REMOTE}:/backup-daily/${SERVER_ID} ${OPTIONSTCHECK} | head -n ${BACKUP_HOLD} | awk '{print $2}' >/tmp/backup_old
    p="/tmp/backup_old"
    while read p; do
      echo $p >/tmp/old_backups
      old_backup=$(cat /tmp/old_backups)
      rclone purge ${REMOTE}:/backup-daily/${SERVER_ID}/${old_backup} ${OPTIONSREMOVE}
    done </tmp/backup_old
fi
}

update_rclone()
{
rcversion="$(curl -s https://api.github.com/repos/rclone/rclone/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")')"
rcstored="$(rclone --version | awk '{print $2}' | tail -n 3 | head -n 1)"
if [ "$rcversion" != "$rcstored" ]; then 
    echo "${output} : rclone will be updated to ${rcversion}"
        wget https://downloads.rclone.org/rclone-current-linux-amd64.zip -O rclone.zip --no-check-certificate 1>/dev/null 2>&1
        unzip rclone.zip 1>/dev/null 2>&1
        rm rclone.zip 1>/dev/null 2>&1
        mv rclone*/rclone /usr/bin 1>/dev/null 2>&1
        rm -r rclone* 1>/dev/null 2>&1
        mkdir -p /rclone 1>/dev/null 2>&1
    echo "${output} : rclone update >> done "
else
    echo "${output} : rclone is up to date || ${rcstored}"
fi
}
discord()
{
  if [ ${DISCORD_WEBHOOK_URL} != 'null' ]; then
    TIME="$((count=${ENDTIME}-${STARTTIME}))"
    duration="$(($TIME / 60)) minutes and $(($TIME % 60)) seconds elapsed."
    echo "${output}  \nTime : ${duration}" >"${DISCORD}"
    message=$(cat "${DISCORD}")
    msg_content=\"$message\"
    USERNAME=\"${DISCORD_NAME_OVERRIDE}\"
    IMAGE=\"${DISCORD_ICON_OVERRIDE}\"
    DISCORD_WEBHOOK_URL="${DISCORD_WEBHOOK_URL}"
    curl -H "Content-Type: application/json" -X POST -d "{\"username\": $USERNAME, \"avatar_url\": $IMAGE, \"content\": $msg_content}" $DISCORD_WEBHOOK_URL
	rm -rf ${DISCORD} 
  else
    echo "${output} Backup complete"
  fi
}
#####
# Some error handling and/or run our backup and tar_create/tar_upload
if [ -f $PIDFILE ]; then
  echo "${output}: Backup already running, remove PID file to rerun" || exit
else
  touch $PIDFILE;
  STARTTIME=$(date +%s)
  echo "${output} : remove old log files"
  remove_logs
  echo "${output} : Rsync Backup is starting"
  do_rsync
  echo "${output} : Rsync Backup done"
  echo "$(rsync_log)"
  tar_gz
  echo "${output} : Tar Backup done"
  sleep 30
     if [ -f $RCCONFIG ]; then
       echo "${output} : starting upload and remove backups"
       remove_folder
       echo "${output} : remove leftover folder >> done"
       upload_tar
       echo "${output} : upload of the backups >> done"
       remove_old_backups
       echo "${output} : purge old backups >> done"
       remove_tar
       echo "${output} : purge old tar files >> done"
     fi
	 ENDTIME=$(date +%s)
     if [ ${DISCORD_WEBHOOK_URL} != 'null' ]; then
       discord
     fi
  echo "${output} : check rclone version >> starting"
  update_rclone
  echo "${output} : check rclone version >> done"
  rm $PIDFILE;
fi

exit 0
