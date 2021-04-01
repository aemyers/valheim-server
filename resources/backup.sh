#!/bin/bash

RESOURCES='{{ RESOURCES }}'
WORLDS="$RESOURCES/save/worlds"
BACKUPS="$RESOURCES/backups"
HISTORY=10

if [[ ! -d "$BACKUPS" ]]; then
	mkdir --parents "$BACKUPS"
fi

# create
stamp=$(date --utc +'%Y%m%d%H%M%S')
echo "creating backup at $BACKUPS/$stamp.tar.gz"
tar --create --verbose --gzip --file="$BACKUPS/$stamp.tar.gz" --directory="$WORLDS" .

# prune
ls -dt "$BACKUPS"/* \
	| tail --lines=+$(( $HISTORY + 1 )) \
	| xargs rm --verbose --force
