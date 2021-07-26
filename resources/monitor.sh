#!/bin/bash

set -o errexit
set -o pipefail

declare -r PROPERTIES='monitor.properties'
declare -r API='https://discord.com/api'

declare -a STEAMID
declare -A PLAYERS
declare -i CONNECTED=0

# echo value for key from properties file
property() {
	local -r key="${1}"
	local -r default="${2:-}"
	local -r file="${3:-$PROPERTIES}"

	local -r entry=$(grep --regexp="^${key}=" "${file}")

	if [[ "${entry}" == '' ]]; then
		echo "${default}"
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

	curl --silent --show-error \
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
	local -ri connected=$1

	CONNECTED=$connected
	topic "${CONNECTED} connected"
	name "valheim - ${CONNECTED}"
}

# send message to discord notify channel
message() {
	local -r content="${1}"
	local -r escaped=$(escape "${content}")
	local -r body='{"content":"'"${escaped}"'"}'

	api 'POST' "/channels/${CHANNEL_NOTIFY}/messages" "${body}"
}

parse() {
	local -r line="${1}"

	# capture connection attempts in progress to associate to character spawn
	if grep --quiet --regexp='Got connection SteamID' <<< "${line}"; then
		local -r message=$(cut --delimiter=':' --fields=7 <<< "${line}")
		local -r id=$(cut --delimiter=' ' --fields=5 <<< "${message}")
		STEAMID+=("${id}")

	# determine if character spawn is occuring after a new connection has been initiated
	elif [[ ! -z "${STEAMID[0]}" ]] && grep --quiet --regexp='Got character ZDOID from' <<< "${line}"; then
		local -r message=$(cut --delimiter=':' --fields=7 <<< "${line}")
		local -r character=$(cut --delimiter=' ' --fields=6 <<< "${message}")

		# ignore character spawn if related to already connected player
		if [[ ! -z "${PLAYERS[${character}]}" ]]; then return; fi

		# assume next connecting player is associated with this first character spawn
		local -r id="${STEAMID[0]}"

		# record connection as complete by removing connection reference and associating character to steamid
		STEAMID=("${STEAMID[@]:1}") # remove first element
		PLAYERS["${character}"]="${id}"

		# announce connection status
		local -r player=$(property "player.${id}" "(SteamID ${id})")
		message "${player} connected as ${character}"
		status $(( CONNECTED + 1 ))

	elif grep --quiet --regexp='Closing socket' <<< "${line}"; then
		local -r message=$(cut --delimiter=':' --fields=7 <<< "${line}")
		local -r id=$(cut --delimiter=' ' --fields=4 <<< "${message}")

		# remove character to steamid association
		local key
		for key in "${!PLAYERS[@]}"; do
			if [[ "${PLAYERS[${key}]}" == "${id}" ]]; then
				unset PLAYERS["${key}"]
				break
			fi
		done

		# update connection status
		status $(( CONNECTED - 1 ))

	elif grep --quiet --regexp='Shuting down' <<< "${line}"; then
		CONNECTED=0
		topic 'server offline'
		name 'valheim - offline'

	elif grep --quiet --regexp='Valheim version' <<< "${line}"; then
		local -r version=$(cut --delimiter=':' --fields=8 <<< "${line}")
		message "started v${version}"
		status 0

	elif grep --quiet --regexp='Connections' <<< "${line}"; then
		local -r message=$(cut --delimiter=':' --fields=7 <<< "${line}")
		local -r squeezed=$(tr --squeeze-repeats ' ' <<< "${message}")
		local -ri connected=$(cut --delimiter=' ' --fields=3 <<< "${squeezed}")
		status $connected

	elif grep --quiet --regexp='Random event set' <<< "${line}"; then
		local -r event=$(cut --delimiter=':' --fields=8 <<< "${line}")
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
