#!/bin/bash

RESOURCES='{{ RESOURCES }}'
BACKUPS="$RESOURCES/backups"

# identify
pushd "$BACKUPS"
latest=$(ls -t | head -n 1)
popd

# upload
aws s3api put-object --body "$BACKUPS/$latest" --bucket aemyers-backup-east --key valheim-latest-backup.tar.gz
