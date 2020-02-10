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

# Skip compression on already compressed files
RSYNC_SKIP_COMPRESS="3fr/3g2/3gp/3gpp/7z/aac/ace/amr/apk/appx/appxbundle/arc/arj/arw/asf/avi/bz2/cab/cr2/crypt[5678]/dat/dcr/deb/dmg/drc/ear/erf/flac/flv/gif/gpg/gz/iiq/iso/jar/jp2/jpeg/jpg/k25/kdc/lz/lzma/lzo/m4[apv]/mef/mkv/mos/mov/mp[34]/mpeg/mp[gv]/msi/nef/oga/ogg/ogv/opus/orf/pef/png/qt/rar/rpm/rw2/rzip/s7z/sfx/sr2/srf/svgz/t[gb]z/tlz/txz/vob/wim/wma/wmv/xz/zip"

# Options to pass to rsync
OPTIONS="--force --ignore-errors --delete \
 --exclude-from=/root/backup_excludes \
 --skip-compress=$RSYNC_SKIP_COMPRESS \
 --backup --backup-dir=$ARCHIVEROOT \
 -aHAXxvP --numeric-ids"

OPTIONSTAR="--warning=no-file-changed --ignore-failed-read --absolute-names --warning=no-file-removed --exclude-from=/root/backup_excludes --use-compress-program=pigz"
 
OPTIONSRCLONE="--config /rclone/rclone.conf \
 -v --checksum --stats-one-line --stats 1s --progress --tpslimit=10 \
 --checkers=8 --transfers=4 --no-traverse --fast-list"

# Make sure our backup tree exists
install -d "${ARCHIVEROOT}"
echo "Installed ${ARCHIVEROOT}"

# Our actual rsyncing function
do_rsync()
{
 # shellcheck disable=SC2086
 # shellcheck disable=SC2164
  rsync ${OPTIONS} -e "ssh -Tx -c aes128-gcm@openssh.com -o Compression=no -i ${SSH_IDENTITY_FILE} -p${SSH_PORT}" "${BACKUPDIR}/" "$ARCHIVEROOT"
}
tar_gz()
{  
 # shellcheck disable=SC2086
 # shellcheck disable=SC2164
 # shellcheck disable=SC2006
cd ${ARCHIVEROOT}
for dir_tar in `find . -maxdepth 1 -type d  | grep -v "^\.$" `; do tar ${OPTIONSTAR} -C ${dir_tar} -cvf ${dir_tar}.tar ./; done
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
rclone --config /rclone/rclone.conf mkdir ${REMOTE}:/system/backup/ 1>/dev/null 2>&1
tree -a -L 1 ${ARCHIVEROOT} | awk '{print $2}' | tail -n +2 | head -n -2 | grep ".tar" >/tmp/tar_folders
p="/tmp/tar_folders"

while read p; do

  echo $p >/tmp/tar
  tar=$(cat /tmp/tar)
  rclone copyto ${ARCHIVEROOT}/${tar} ${REMOTE}:/system/backup/${tar} ${OPTIONSRCLONE} --include "*.tar"

done </tmp/tar_folders

}
upload_tar_part2()
{
rrc="/rclone/rclone.conf"
if [ -f $rrc ]; then 
  upload_tar
  echo "$(date) :  Upload Backup done"
else
  echo "$(date) :  NO rclone.conf Found"
  echo "$(date) :  Backups not Uploaded"
fi
}
# Some error handling and/or run our backup and tar_create/tar_upload
if [ -f $PIDFILE ]; then
  echo "$(date): Backup already running, remove PID file to rerun"
  exit
else
  touch $PIDFILE;
  # Now the actual transfer
  do_rsync
  echo "$(date) : Rsync Backup done"
  tar_gz
  echo "$(date) : Tar Backup done"
  upload_tar_part2
  rm $PIDFILE;
fi

exit 0
