#!/bin/bash

RESOURCES='{{ RESOURCES }}'

set -m
journalctl --unit=valheim --follow --lines=0 &

sudo systemctl stop valheim
"$RESOURCES/update.sh"
sudo systemctl start valheim

fg
