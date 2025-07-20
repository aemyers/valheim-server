#!/bin/bash

set -o errexit
set -o pipefail

readonly UTILS=utils
. "${UTILS}/properties.sh"
. "${UTILS}/discord.sh"

declare -ri DEATH=0
declare -ri JOIN=20

. util/json.sh
. util/discord.sh
. util/properties.sh

declare -r DISCORD_TOKEN=$(properties_read "${PROPERTIES}" "token")
declare -r CHANNEL_NOTIFY=$(properties_read "${PROPERTIES}" "channel.notify")
declare -r CHANNEL_STATUS=$(properties_read "${PROPERTIES}" "channel.status")

declare -i COUNT=0

status() {
	local -ri count=$1

	COUNT=$count
	discord_topic "${CHANNEL_NOTIFY}" "${COUNT} connected"
	discord_name "${CHANNEL_STATUS}" "valheim - ${COUNT} connected"
}

parse_content() {
	local -r line="${1}"
	# 'Apr 03 02:00:26 ovh-va-valheim valheim_server.x86_64[92662]: 04/03/2024 02:00:26: Random event set:army_theelder'

	local -r raw=$(cut --delimiter=':' --fields=7- <<< "${line}")
	# ' Random event set:army_theelder'

	local -r result="${raw:1}"
	# 'Random event set:army_theelder'

	echo "${result}"
}

parse() {
	local -r message=$(parse_content "${1}")

	# 'Got character ZDOID from Name With Spaces  : 1234567890:1' # '<id>:<seconds connected>', '0:0' is death
	if grep --quiet --regexp='^Got character ZDOID from' <<< "${message}"; then
		local -r data=$(cut --delimiter=' ' --fields=5- <<< "${message}") # 'Name With Spaces  : 1234567890:1'
		local -r duration=$(cut --delimiter=':' --fields=3 <<< "${data}") # '1'
		if [ $duration -ne $DEATH ] && [ $duration -lt $JOIN ]; then
			local -r character=$(cut --delimiter=':' --fields=1 <<< "${data}")  # 'Name With Spaces '
			local -r trimmed=$(sed -e 's/[[:space:]]*$//' <<< "${character}")   # 'Name With Spaces'
			discord_message "${CHANNEL_NOTIFY}" "${trimmed}: I HAVE ARRIVED!"
			status $(( COUNT + 1 ))
		fi

	# "Closing socket 76561199054480035"
	elif grep --quiet --regexp='^Closing socket' <<< "${message}"; then
		status $(( COUNT - 1 ))

	# "Player connection lost server "valheim.aemyers.com" that has join code 123456, now 1 player(s)"
	elif grep --quiet --regexp='^Player connection lost' <<< "${message}"; then
		local -ri after=$(cut --delimiter='"' --fields=3 <<< "${message}")
		local -ri count=$(cut --delimiter=' ' --fields=8 <<< "${after}")
		status $count

	# "Apr 08 21:36:21 ovh-va-valheim systemd[1]: Stopping valheim..."
	elif grep --quiet --regexp='Stopping valheim' <<< "${message}"; then
		COUNT=0
		topic 'server offline'
		name 'valheim - offline'

	# "Valheim version: l-0.217.38 (network version 20)"
	elif grep --quiet --regexp='^Valheim version' <<< "${message}"; then
		local -r data=$(cut --delimiter=' ' --fields=3 <<< "${message}")
		local -r version=$(cut --delimiter='-' --fields=2 <<< "${data}")
		discord_message "${CHANNEL_NOTIFY}" "started version ${version}"
		status 0

 	# " Connections 2 ZDOS:222503  sent:57 recv:216"
	elif grep --quiet --regexp='^ Connections' <<< "${message}"; then
		local -ri count=$(cut --delimiter=' ' --fields=3 <<< "${message}")
		status $count

	# "Random event set:army_theelder"
	elif grep --quiet --regexp='^Random event set' <<< "${message}"; then
		local -r event=$(cut --delimiter=':' --fields=2 <<< "${message}")
		local -r description=$(properties_read "${PROPERTIES}" "event.${event}")
		discord_message "${CHANNEL_NOTIFY}" "random event started: \"${description}\" (${event})"

	fi
}

main() {
	local -r service=$(properties_read "${PROPERTIES}" "service")

	while true; do # until killed

		journalctl --unit="${service}" --lines=0 --follow \
			| while read -r line; do
				parse "${line}"
			done

		echo "exit code: $?"

	done
}

main "${@}"
