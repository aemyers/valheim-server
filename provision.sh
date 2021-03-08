#!/bin/bash

# config
INSTANCE=/opt/valheim
ACCOUNT=valheim

# secrets
read -p 'password: ' password

# prepare
dpkg --add-architecture i386
apt --yes update
apt --yes upgrade
apt --yes install lib32gcc1 lib32stdc++6 steamcmd

# account
groupadd  "$ACCOUNT"
useradd --create-home --gid "$ACCOUNT" "$ACCOUNT"

# valheim
mkdir "$INSTANCE"
chown -R "$ACCOUNT":"$ACCOUNT" "$INSTANCE"
cp --recursive home/. "/home/$ACCOUNT/"
chown -R "$ACCOUNT":"$ACCOUNT" "/home/$ACCOUNT"
su - "$ACCOUNT" update.sh

# service
sed "s/{password}/${password}/g" valheim.service > /etc/systemd/system/valheim.service
systemctl daemon-reload
systemctl enable valheim.service
systemctl start valheim
