#!/bin/bash

# environment
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

# install
mkdir "$INSTANCE"
chown -R "$ACCOUNT":"$ACCOUNT" "$INSTANCE"
su - "$ACCOUNT" update.sh

# config
cp --recursive home/. "/home/$ACCOUNT/"
sed -i "s/{INSTANCE}/${INSTANCE}/g" /home/"$ACCOUNT"/*
sed -i "s/{ACCOUNT}/${ACCOUNT}/g" /home/"$ACCOUNT"/*
chown -R "$ACCOUNT":"$ACCOUNT" "/home/$ACCOUNT"

# backup
command="/home/$ACCOUNT/backup.sh > /home/$ACCOUNT/backup.log 2>&1"
schedule="0 * * * *"
echo "$schedule $command" | crontab -u "$ACCOUNT" -

# service
sed "s/{password}/${password}/g" valheim.service > /etc/systemd/system/valheim.service
systemctl daemon-reload
systemctl enable valheim.service
systemctl start valheim
