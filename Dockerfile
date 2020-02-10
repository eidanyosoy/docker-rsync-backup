FROM alpine:latest
MAINTAINER Johan Swetzén <johan@swetzen.com>

ENV REMOTE_HOSTNAME="" \
    BACKUPDIR="/home" \
    ARCHIVEROOT="/backup" \
    EXCLUDES="/backup_excludes" \
    SSH_PORT="22" \
    SSH_IDENTITY_FILE="/root/.ssh/id_rsa" \
    CRON_TIME="0 1 * * *"

RUN apk update
RUN apk upgrade
RUN apk add --no-cache rsync openssh-client tar nano wget 

RUN echo http://dl-cdn.alpinelinux.org/alpine/edge/community/ >> /etc/apk/repositories && \
    apk update && apk upgrade && \
    apk add --no-cache \
        ca-certificates \
        logrotate \
        shadow \
        bash \
        bc \
        findutils \
        coreutils \
        openssl \
        curl \
        libxml2-utils \
        htop \
        nano \
        mc

RUN wget https://downloads.rclone.org/rclone-current-linux-amd64.zip -O rclone.zip --no-check-certificate && \
    unzip rclone.zip && rm rclone.zip && \
    mv rclone*/rclone /usr/bin && rm -r rclone* && \
    mkdir -p /rclone

COPY docker-entrypoint.sh /usr/local/bin/
COPY backup.sh /backup.sh
COPY backup_excludes /root/backup_excludes

ENTRYPOINT ["docker-entrypoint.sh"]

CMD /backup.sh && crond -f
