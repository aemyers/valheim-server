#!/bin/bash

RESOURCES='{{ RESOURCES }}'
WORLDS="${RESOURCES}/save/worlds_local"
BACKUPS="${RESOURCES}/backups"
BUCKET='aemyers-backup-east'
KEY='valheim-latest-backup.tar.gz'

SOURCE=$1

# if source is not supplied, list local and offsite
if [ "${SOURCE}" == '' ]; then
        echo 'local:'
        find "${BACKUPS}" -type f -printf '%TFT%.8TT%Tz %f\n' | sort -r
        echo
        echo 'offsite:'
        aws s3api list-object-versions --bucket $BUCKET --prefix $KEY --output text \
                --query 'reverse(sort_by(Versions[*], &LastModified)) | [*].[LastModified, VersionId]'
        exit
fi

# if source does not match local file, download as offsite version-id
if [ ! -f "${BACKUPS}/${SOURCE}" ]; then
	aws s3api get-object --bucket "${BUCKET}" --prefix "${KEY}" --version-id "${SOURCE}"
	SOURCE="${KEY}"
fi

# move existing to backup
timestamp=$(date -u +'%Y%m%d%H%M%S')
backup="${BACKUPS}/${timestamp}"
mkdir "${backup}"
mv "${WORLDS}/world.db*" "${backup}/"
mv "${WORLDS}/world.fwl*" "${backup}/"

# restore from local file
tar --extract --verbose --file="${SOURCE}" --directory="${WORLDS}"

# rename old
mv "${WORLDS}/world.db.old" '${WORLDS}/world.db'
mv "${WORLDS}/world.fwl.old" '${WORLDS}/world.fwl'
