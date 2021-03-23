#!/bin/bash

SOURCE=/home/{ACCOUNT}/.config/unity3d/IronGate/Valheim/worlds/
BACKUPS=/var{INSTANCE}/backups
HISTORY=10

if [[ ! -d "$BACKUPS" ]]; then
	mkdir --parents "$BACKUPS"
fi

# create
stamp=$(date --utc +'%Y%m%d%H%M%S')
echo "creating backup at $BACKUPS/$stamp.tar.gz"
tar --directory="$SOURCE" --create --gzip --verbose --file="$BACKUPS/$stamp.tar.gz" .

# prune
ls -dt "$BACKUPS"/* \
	| tail --lines=+$(( $HISTORY + 1 ))) \
	| xargs rm --verbose --force
