#!/bin/sh

#########################################################
# Script to do incremental rsync backups
# Adapted from script found on the rsync.samba.org
# Brian Hone 3/24/2002
# Updated 2015-10-09 by Johan Swetzén
# Adapted for Docker 2017-11-14 by Johan Swetzén
# This script is freely distributed under the GPL
#########################################################

##################################
# Required environment variables
##################################

# REMOTE_HOSTNAME (default: "")
# - Hostname of the server being backed up
# Optional. The SSH host keys for this host will be scanned and added to
# known_hosts to enable a connection. Not used for the actual backup command.

# BACKUPDIR (default: /home)
# - This is the path to the directory you want to archive
# - For a remote SSH connection, specify it like you would an SCP command:
#     user@host:/directory

# SSH_PORT (default: 22)
# SSH port number for the remote server being backed up.

# SSH_IDENTITY_FILE (default: /root/.ssh/id_rsa)
# Set this to use an SSH key generated outside the container. Make sure it has
# no passphrase, or it cannot be used by the script.
# If mounting .ssh to a volume, do not mount it to /root/.ssh. This will
# cause problems with the config file having the wrong owner. Instead do this:
#
# --volume /home/mysuer/.ssh:/ssh-keys --env SSH_IDENTITY_FILE=/ssh-keys/id_rsa

# EXCLUDES (default: "")
# - A semicolon separated list of exclude patterns. See the FILTER RULES section
#   of the rsync man page.
# - The patterna are split by ; and added to an exclude file passed to rsync.
# - A limitation is that semicolon may not be present in any of the patterns.

# ARCHIVEROOT (default: /backup)
# - Root directory to backup to
# - A folder structure like this will be created:
# /backup
# ├── 2017-11-06 #Incremental backup for each day
# ├── 2017-11-07
# ├── 2017-11-08
# └── main # The latest backup, full

# CRON_TIME (default: "0 1 * * *")
# - Time of day to do backup
# - Specified in UTC
# TODO: Allow Timezone to be specified

#########################################
# From here on out, you probably don't  #
#   want to change anything unless you  #
#   know what you're doing.             #
#########################################

PIDFILE=/var/run/backup.pid

# Skip compression on already compressed files
RSYNC_SKIP_COMPRESS="3fr/3g2/3gp/3gpp/7z/aac/ace/amr/apk/appx/appxbundle/arc/arj/arw/asf/avi/bz2/cab/cr2/crypt[5678]/dat/dcr/deb/dmg/drc/ear/erf/flac/flv/gif/gpg/gz/iiq/iso/jar/jp2/jpeg/jpg/k25/kdc/lz/lzma/lzo/m4[apv]/mef/mkv/mos/mov/mp[34]/mpeg/mp[gv]/msi/nef/oga/ogg/ogv/opus/orf/pef/png/qt/rar/rpm/rw2/rzip/s7z/sfx/sr2/srf/svgz/t[gb]z/tlz/txz/vob/wim/wma/wmv/xz/zip"
# RSYNC_SKIP_COMPRESS="3fr"

# Directory which holds our current datastore
CURRENT=main

# Options to pass to rsync
OPTIONS="--force --ignore-errors --delete \
 --exclude-from=/backup_excludes \
 --skip-compress=$RSYNC_SKIP_COMPRESS \
 --backup --backup-dir=$ARCHIVEROOT \
 -aHAXxv --numeric-ids --progress"

# Make sure our backup tree exists
install -d "${ARCHIVEROOT}/${CURRENT}"
echo "Installed ${ARCHIVEROOT}/${CURRENT}"

OPTIONSTAR="--warning=no-file-changed --ignore-failed-read --absolute-names --warning=no-file-removed"

# Our actual rsyncing function
do_rsync()
{
  # ShellCheck: Allow unquoted OPTIONS because it contain spaces
  # shellcheck disable=SC2086
  rsync ${OPTIONS} -e "${BACKUPDIR}" "$ARCHIVEROOT/$CURRENT"
}
tar_gz()
{  
 # ShellCheck: Allow unquoted OPTIONS because it contain spaces
 # shellcheck disable=SC2086

cd "${ARCHIVEROOT}/${CURRENT}"
for dir in `find . -maxdepth 1 -type d  | grep -v "^\.$" `; do tar ${OPTIONSTAR} -cvf ${dir}.tar ${dir}; done
}

  # ShellCheck: Allow unquoted OPTIONS because it contain spaces
  # shellcheck disable=SC2086
#tar ${OPTIONSTAR} -C "$ARCHIVEROOT/$CURRENT"-cvf "$ARCHIVEROOT/$CURRENT/"${folder_var}.tar ./

# Some error handling and/or run our backup and accounting
if [ -f $PIDFILE ]; then
  echo "$(date): backup already running, remove pid file to rerun"
  exit
else
  touch $PIDFILE;
  # Now the actual transfer
  do_rsync
  echo "Rsync Backup done"
  tar_gz
  echo "Tar Backup done"
  rm $PIDFILE;
fi

exit 0
