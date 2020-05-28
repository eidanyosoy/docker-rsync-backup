FROM alpine:latest
#THX TO Johan Swetzén <johan@swetzen.com> for Build up the basic parts
MAINTAINER MrDoob <fuckoff@all.com>

ENV BACKUPDIR="/home" \
    ARCHIVEROOT="/backup" \
    EXCLUDES="/backup_excludes" \
    SSH_PORT="22" \
    SSH_IDENTITY_FILE="/root/.ssh/id_rsa" \
    CRON_TIME="0 1 * * *" \
    LOGS="/log" \
    SET_CONTAINER_TIMEZONE="true" \
    CONTAINER_TIMEZONE="Europe/Berlin" \
    BACKUP_HOLD="15" \
    SERVER_ID="docker" \
    RSYNC_COMPRESS_LEVEL="2" \
    DISCORD_WEBHOOK_URL="" \
    DISCORD_ICON_OVERRIDE="https://i.imgur.com/KorF8zC.png" \
    DISCORD_NAME_OVERRIDE="BACKUP"

RUN echo http://dl-cdn.alpinelinux.org/alpine/edge/community/ >> /etc/apk/repositories && \
    apk update && apk upgrade && \
    apk add --no-cache \
        ca-certificates \
        rsync \
        openssh-client \
        tar \
        wget \
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
        tree \
        nano \
        pigz \
        mc \ 
        tzdata \
        openntpd \
        grep

RUN wget https://downloads.rclone.org/rclone-current-linux-amd64.zip -O rclone.zip --no-check-certificate && \
    unzip rclone.zip && rm rclone.zip && \
    mv rclone*/rclone /usr/bin && rm -r rclone* && \
    mkdir -p /rclone

COPY docker-entrypoint.sh /usr/local/bin/
COPY backup.sh /backup.sh
ADD backup_excludes /root/backup_excludes
RUN chmod +x /root/backup_excludes

ENTRYPOINT ["docker-entrypoint.sh"]

CMD /backup.sh && crond -f
