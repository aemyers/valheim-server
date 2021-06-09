#!/bin/bash

journalctl --unit=valheim --follow --lines=0 &
sudo systemctl restart valheim
fg
