#!/bin/bash

SOURCE=/home/{ACCOUNT}/.config/unity3d/IronGate/Valheim/worlds/
BACKUPS=/var{INSTANCE}/backups
HISTORY=10

if [[ ! -d "$BACKUPS" ]]; then
	mkdir --parents "$BACKUPS"
fi

# create
timestamp=$(date +%Y%m%d%H%M%S)
tar --create --gzip --verbose --file="$BACKUPS/$timestamp.tar.gz" "$SOURCE"

# prune
ls -dt "$BACKUPS"/* \
	| tail --lines=+$(( $HISTORY + 1 )) \
	| xargs rm --force
