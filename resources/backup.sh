#!/bin/bash

RESOURCES='{{ RESOURCES }}'
WORLDS="$RESOURCES/save/worlds_local"
BACKUPS="$RESOURCES/backups"
HISTORY=10

if [[ ! -d "$BACKUPS" ]]; then
	mkdir --parents "$BACKUPS"
fi

# create
stamp=$(date --utc +'%Y%m%d%H%M%S')
file="$BACKUPS/$stamp.tar.gz"
echo "creating backup at $file"
pushd "$WORLDS"
tar --create --verbose --gzip --file="$file" *.old
popd

# prune
ls -dt "$BACKUPS"/* \
	| tail --lines=+$(( $HISTORY + 1 )) \
	| xargs rm --verbose --force
