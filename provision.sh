#!/bin/bash

set -o xtrace

# environment
ACCOUNT=valheim
RESOURCES=/var/opt/valheim
INSTALL=/opt/valheim
SERVER_SERVICE=valheim.service
MONITOR_SERVICE=valheim-monitor.service

# prepare
dpkg --add-architecture i386
apt update
apt --yes upgrade
apt --yes install lib32gcc1 lib32stdc++6 steamcmd
apt --yes install awscli

# account
groupadd "$ACCOUNT"
useradd --system --home-dir "$RESOURCES" --gid "$ACCOUNT" "$ACCOUNT"

# resources
mkdir --parents "$RESOURCES"
cp --recursive resources/. "$RESOURCES/"
sed -i "s|{{ RESOURCES }}|${RESOURCES}|g" "$RESOURCES"/*.sh
sed -i "s|{{ INSTALL }}|${INSTALL}|g" "$RESOURCES"/*.sh
chown -R "$ACCOUNT":"$ACCOUNT" "$RESOURCES"
chmod +x "$RESOURCES"/*.sh

# install
mkdir --parents "$INSTALL"
chown -R "$ACCOUNT":"$ACCOUNT" "$INSTALL"
su - "$ACCOUNT" "$RESOURCES/update.sh"

# backup (every hour)
schedule='0 * * * *'
command="$RESOURCES/backup.sh > $RESOURCES/backup.log 2>&1"
echo "$schedule $command" | crontab -u "$ACCOUNT" -

# offsite backup (11 AM UTC = 4 AM MT)
schedule='5 11 * * *'
command="$RESOURCES/offsite.sh > $RESOURCES/offsite.log 2>&1"
echo "$schedule $command" | crontab -u "$ACCOUNT" -

# services
cat server.service \
	| sed "s|{{ RESOURCES }}|${RESOURCES}|g" \
	| sed "s|{{ INSTALL }}|${INSTALL}|g" \
	> "/etc/systemd/system/${SERVER_SERVICE}"
cat monitor.service \
        | sed "s|{{ RESOURCES }}|${RESOURCES}|g" \
        | sed "s|{{ INSTALL }}|${INSTALL}|g" \
        > "/etc/systemd/system/${MONITOR_SERVICE}"
systemctl daemon-reload
systemctl enable --now "${SERVER_SERVICE}" "${MONITOR_SERVICE}"
