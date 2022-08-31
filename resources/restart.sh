#!/bin/bash

RESOURCES='{{ RESOURCES }}'

journalctl --unit=valheim --follow --lines=0 &

sudo systemctl stop valheim
"$RESOURCES/update.sh"
sudo systemctl start valheim

fg
