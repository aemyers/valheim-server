#!/bin/bash

installed=$(grep -Po '(?<="buildid"\t\t").*(?=")' '{INSTALL}/steamapps/appmanifest_896660.acf')
info=$(/usr/games/steamcmd +login anonymous +app_info_update 1 +app_info_print 896660 +quit)
available=$(echo "$info" \
	| sed -n '/"branches"/,/^}/p' \
	| sed -n '/"public"/,/}/p' \
	| grep -Po '(?<="buildid"\t\t").*(?=")' \
	)

echo "installed: ${installed}"
echo "available: ${available}"
if [[ "${installed}" == "${available}" ]]; then
	echo 'already installed'
	exit
fi

echo 'updating...'
/usr/games/steamcmd +runscript '{RESOURCES}/update.steam'
