#!/bin/sh

set -o errexit
set -o pipefail

readonly UTILS=utils
. "${UTILS}/properties.sh"
. "${UTILS}/discord.sh"

readonly PROPERTIES='monitor.properties'

readonly DISCORD_TOKEN=$(properties_read "${PROPERTIES}" "token")
readonly CHANNEL_NOTIFY=$(properties_read "${PROPERTIES}" "channel.notify")
readonly CHANNEL_STATUS=$(properties_read "${PROPERTIES}" "channel.status")

readonly DEATH=0
readonly JOIN=20

COUNT=0

status() {
	count=$1

	COUNT=$count
	discord_topic "${CHANNEL_NOTIFY}" "${COUNT} connected"
	discord_name "${CHANNEL_STATUS}" "valheim - ${COUNT} connected"
}

parse_content() {
	line="${1}"
	# 'Apr 03 02:00:26 ovh-va-valheim valheim_server.x86_64[92662]: 04/03/2024 02:00:26: Random event set:army_theelder'

	raw=$(cut --delimiter=':' --fields=7- <<< "${line}")
	# ' Random event set:army_theelder'

	result="${raw:1}"
	# 'Random event set:army_theelder'

	echo "${result}"
}

parse() {
	content=$(parse_content "${1}")

	# 'Got character ZDOID from Name With Spaces  : 1234567890:1' # '<id>:<seconds connected>', '0:0' is death
	if grep --quiet --regexp='^Got character ZDOID from' <<< "${content}"; then
		data=$(cut --delimiter=' ' --fields=5- <<< "${content}") # 'Name With Spaces  : 1234567890:1'
		duration=$(cut --delimiter=':' --fields=3 <<< "${data}") # '1'
		if [ $duration -ne $DEATH ] && [ $duration -lt $JOIN ]; then
			character=$(cut --delimiter=':' --fields=1 <<< "${data}")  # 'Name With Spaces '
			trimmed=$(sed -e 's/[[:space:]]*$//' <<< "${character}")   # 'Name With Spaces'
			discord_message "${CHANNEL_NOTIFY}" "${trimmed}: I HAVE ARRIVED!"
			status $(( COUNT + 1 ))
		fi

	# "Closing socket 76561199054480035"
	elif grep --quiet --regexp='^Closing socket' <<< "${content}"; then
		status $(( COUNT - 1 ))

	# "Player connection lost server "valheim.aemyers.com" that has join code 123456, now 1 player(s)"
	elif grep --quiet --regexp='^Player connection lost' <<< "${content}"; then
		after=$(cut --delimiter='"' --fields=3 <<< "${content}")
		count=$(cut --delimiter=' ' --fields=8 <<< "${after}")
		status $count

	# "Apr 08 21:36:21 ovh-va-valheim systemd[1]: Stopping valheim..."
	elif grep --quiet --regexp='Stopping valheim' <<< "${content}"; then
		COUNT=0
		topic 'server offline'
		name 'valheim - offline'

	# "Valheim version: l-0.217.38 (network version 20)"
	elif grep --quiet --regexp='^Valheim version' <<< "${content}"; then
		data=$(cut --delimiter=' ' --fields=3 <<< "${content}")
		version=$(cut --delimiter='-' --fields=2 <<< "${data}")
		discord_message "${CHANNEL_NOTIFY}" "started version ${version}"
		status 0

 	# " Connections 2 ZDOS:222503  sent:57 recv:216"
	elif grep --quiet --regexp='^ Connections' <<< "${content}"; then
		count=$(cut --delimiter=' ' --fields=3 <<< "${content}")
		status $count

	# "Random event set:army_theelder"
	elif grep --quiet --regexp='^Random event set' <<< "${content}"; then
		event=$(cut --delimiter=':' --fields=2 <<< "${content}")
		description=$(properties_read "${PROPERTIES}" "event.${event}")
		discord_message "${CHANNEL_NOTIFY}" "random event started: \"${description}\" (${event})"

	fi
}

main() {
	service=$(properties_read "${PROPERTIES}" "service")

	while true; do # until killed

		journalctl --unit="${service}" --lines=0 --follow \
			| while read -r line; do
				parse "${line}"
			done

		echo "exit code: $?"

	done
}

main "${@}"
