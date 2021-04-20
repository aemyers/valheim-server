#!/bin/bash

INSTALL='{{ INSTALL }}'
APPID='896660' # Valheim Dedicated Server https://steamdb.info/app/896660/depots/?branch=public
STEAMCMD='/usr/games/steamcmd'

installed=$(grep -Po '(?<="buildid"\t\t").*(?=")' "$INSTALL/steamapps/appmanifest_${APPID}.acf")

info=$("$STEAMCMD" \
	+login anonymous \
	+app_info_update 1 \
	+app_info_print "$APPID" \
	+quit)
available=$(echo "$info" \
	| sed -n '/"branches"/,/^}/p' \
	| sed -n '/"public"/,/}/p' \
	| grep -Po '(?<="buildid"\t\t").*(?=")' \
	)

echo "installed: $installed"
echo "available: $available"

if [[ "$installed" == "$available" ]]; then
	echo 'no update available'
	exit
fi

echo 'update found; installing...'
"$STEAMCMD" \
	+login anonymous \
	+force_install_dir "$INSTALL" \
	+app_update "$APPID" validate \
	+quit
