#!/bin/bash

set -o errexit
set -o pipefail

declare -r PROPERTIES='monitor.properties'
declare -r API='https://discord.com/api'

declare -ri DEATH=0
declare -ri JOIN=20
declare -ri RATE=1

declare -i COUNT=0
declare -i LAST=0

# echo value for key from properties file
property() {
	local -r key="${1}"
	local -r file="${2:-$PROPERTIES}"

	local -r entry=$(grep --regexp="^${key}=" "${file}")

	if [[ "${entry}" == '' ]]; then
		echo "${key}"
		return
	fi

	cut --delimiter='=' --fields='2-' <<< "${entry}"
}

# echo formatted text for json string
escape() {
	local result="${1}"

	result=${result//\\/\\\\}    # backslash
	result=${result//\"/\\\"}    # double quote
	result=${result//\//\\\/}    # forward slash
	result=${result//$'\t'/\\\t} # tab
	result=${result//$'\n'/\\\n} # newline
	result=${result//$'\r'/\\\r} # carriage return
	result=${result//$'\f'/\\\f} # form feed
	result=${result//$'\b'/\\\b} # backspace

	echo -n "${result}"
}

# call discord api
api() {
	local -r method="${1}"
	local -r path="${2}"
	local -r body="${3}"

	local -ri now=$(date +%s)
	local -ri since=$($now - $LAST)
	if [ $since -lt $RATE ]; then sleep $RATE; fi

	echo '---'
	echo
	echo "api call: ${method} ${path}"
	echo "api body: ${body}"

	curl --silent --show-error --dump-header - \
		--request "${method}" \
		--header "Authorization: Bot ${TOKEN}" \
		--header 'Content-type: application/json' \
		--data "${body}" \
		"${API}${path}"
}

# set discord notify channel topic
topic() {
	local -r topic="${1}"
	local -r escaped=$(escape "${topic}")
	local -r body='{"topic":"'"${escaped}"'"}'

	api 'PATCH' "/channels/${CHANNEL_NOTIFY}" "${body}"
}

# set discord status channel name
name() {
	local -r name="${1}"
	local -r escaped=$(escape "${name}")
	local -r body='{"name":"'"${escaped}"'"}'

	api 'PATCH' "/channels/${CHANNEL_STATUS}" "${body}"
}

# update discord with server status
status() {
	local -ri count=$1

	COUNT=$count
	topic "${COUNT} connected"
	name "valheim - ${COUNT} connected"
}

# send message to discord notify channel
message() {
	local -r content="${1}"
	local -r escaped=$(escape "${content}")
	local -r body='{"content":"'"${escaped}"'"}'

	api 'POST' "/channels/${CHANNEL_NOTIFY}/messages" "${body}"
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
			message "${trimmed}: I HAVE ARRIVED!"
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
		message "started version ${version}"
		status 0

 	# " Connections 2 ZDOS:222503  sent:57 recv:216"
	elif grep --quiet --regexp='^ Connections' <<< "${message}"; then
		local -ri count=$(cut --delimiter=' ' --fields=3 <<< "${message}")
		status $count

	# "Random event set:army_theelder"
	elif grep --quiet --regexp='^Random event set' <<< "${message}"; then
		local -r event=$(cut --delimiter=':' --fields=2 <<< "${message}")
		local -r description=$(property "event.${event}")
		message "random event started: \"${description}\" (${event})"

	fi
}

main() {
	declare -r TOKEN=$(property "token")
	declare -r CHANNEL_NOTIFY=$(property "channel.notify")
	declare -r CHANNEL_STATUS=$(property "channel.status")

	local -r service=$(property "service")

	while true; do # until killed

		journalctl --unit="${service}" --lines=0 --follow \
			| while read -r line; do
				parse "${line}"
			done

		echo "exit code: $?"

	done
}

main "${@}"
