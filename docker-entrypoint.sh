#!/bin/sh
echo "${CRON_TIME} /backup.sh" > /crontab.conf
crontab /crontab.conf

# Generate ssh keys if needed
if [ ! -f "${SSH_IDENTITY_FILE}" ]; then
  install -d "$(dirname "${SSH_IDENTITY_FILE}")"
  ssh-keygen -q -trsa -b2048 -N "" -f "${SSH_IDENTITY_FILE}"
  printf "\nSSH keys generated at %s. Public key:\n\n" "${SSH_IDENTITY_FILE}"
  cat "${SSH_IDENTITY_FILE}.pub"
  printf "\n"
fi

# Create backup excludes file by splitting the EXCLUDES variable
touch /backup_excludes
IFS=';'
for exclude in ${EXCLUDES}; do
  echo "${exclude}" >> /backup_excludes
done

# Set the timezone. Base image does not contain the setup-timezone script, so an alternate way is used.
if [ "$SET_CONTAINER_TIMEZONE" = "true" ]; then
    cp /usr/share/zoneinfo/${CONTAINER_TIMEZONE} /etc/localtime && \
	echo "${CONTAINER_TIMEZONE}" >  /etc/timezone && \
	echo "Container timezone set to: $CONTAINER_TIMEZONE"
else
	echo "Container timezone not modified"
fi

ntpd -s

exec "$@"
