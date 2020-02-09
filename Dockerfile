FROM alpine:3.6
MAINTAINER Johan Swetzén <johan@swetzen.com>

ENV REMOTE_HOSTNAME="" \
    BACKUPDIR="/home" \
    ARCHIVEROOT="/backup" \
    EXCLUDES="/backup_excludes" \
    CRON_TIME="0 1 * * *"

RUN apk add --no-cache rsync openssh-client tar

COPY docker-entrypoint.sh /usr/local/bin/
COPY backup.sh /backup.sh
COPY backup_excludes /backup_excludes

ENTRYPOINT ["docker-entrypoint.sh"]

CMD /backup.sh && crond -f
