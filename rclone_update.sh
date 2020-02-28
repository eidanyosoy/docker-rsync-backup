#!/bin/sh

# RCLONE_UPDATE (default: "@weekly")
# - Time of day to do update for rclone

#########################################
# From here on out, you probably don't  #
#   want to change anything unless you  #
#   know what you're doing.             #
#########################################
PIDFILE=/var/run/rclone_update.pid

update_rclone()
{
rcversion="$(curl -s https://api.github.com/repos/rclone/rclone/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")')"
rcstored="$(rclone --version | awk '{print $2}' | tail -n 3 | head -n 1)"
if [ "$rcversion" != "$rcstored" ]; then 
    echo "$(date) : rclone will be updated to ${rcversion}"
    wget https://downloads.rclone.org/rclone-current-linux-amd64.zip -O rclone.zip --no-check-certificate 1>/dev/null 2>&1
    unzip rclone.zip 1>/dev/null 2>&1
	rm rclone.zip 1>/dev/null 2>&1
    mv rclone*/rclone /usr/bin 1>/dev/null 2>&1
	rm -r rclone* 1>/dev/null 2>&1
    mkdir -p /rclone 1>/dev/null 2>&1
    echo "$(date) : rclone update >> done "
else
    echo "$(date) : rclone is up to date"
fi
}

# Some error handling of updater
if [ -f $PIDFILE ]; then
  echo "$(date): rclone updater already running, remove PID file to rerun"
  exit
else
  touch $PIDFILE;
  # Now the actual transfer
  echo "$(date) : rclone updater starting"
  update_rclone
  rm $PIDFILE;
fi

exit 0
