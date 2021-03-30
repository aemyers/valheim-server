#!/bin/bash

set -o xtrace

# environment
ACCOUNT=valheim
RESOURCES=/var/opt/valheim
INSTALL=/opt/valheim

# prepare
dpkg --add-architecture i386
apt update
apt --yes upgrade
apt --yes install lib32gcc1 lib32stdc++6 steamcmd

# account
groupadd  "$ACCOUNT"
useradd --system --home-dir "$RESOURCES" --gid "$ACCOUNT" "$ACCOUNT"

# resources
mkdir --parents "$RESOURCES"
cp --recursive resources/. "$RESOURCES/"
find "$RESOURCES" -type f -exec sed -i "s|{RESOURCES}|${RESOURCES}|g" {} \;
find "$RESOURCES" -type f -exec sed -i "s|{INSTALL}|${INSTALL}|g" {} \;
chown -R "$ACCOUNT":"$ACCOUNT" "$RESOURCES"

# install
mkdir --parents "$INSTALL"
chown -R "$ACCOUNT":"$ACCOUNT" "$INSTALL"
su - "$ACCOUNT" "$RESOURCES/update.sh"

# backup
schedule="0 * * * *"
command="$RESOURCES/backup.sh > $RESOURCES/backup.log 2>&1"
echo "$schedule $command" | crontab -u "$ACCOUNT" -

# service
cat systemd.service \
	| sed "s|{RESOURCES}|${RESOURCES}|g" \
	| sed "s|{INSTALL}|${INSTALL}|g" \
	> /etc/systemd/system/valheim.service
systemctl daemon-reload
systemctl enable valheim.service
systemctl start valheim
