#!/bin/bash

set -o errexit
set -o pipefail

declare -r PROPERTIES='monitor.properties'
declare -r API='https://discord.com/api'

declare -a CONNECTING
declare -A PLAYERS
declare -i COUNT=0

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

	echo
	echo "api call: ${method} ${path}"
	echo "api body: ${body}"

	curl --silent --show-error --dump-header - \
		--request "${method}" \
		--header "Authorization: Bot ${TOKEN}" \
		--header 'Content-type: application/json' \
		--data "${body}" \
		"${API}${path}"

	echo '----'
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
	name "valheim - ${COUNT}"
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

	# capture connection attempts in progress to associate to character spawn - steam
	# Got connection SteamID 123456789
	if grep --quiet --regexp='Got connection SteamID' <<< "${line}"; then
		local -r message=$(cut --delimiter=':' --fields=7 <<< "${line}")
		local -r id=$(cut --delimiter=' ' --fields=5 <<< "${message}")
		CONNECTING+=("${id}")

	# capture connection attempts in progress to associate to character spawn - crossplay
	# PlayFab socket with remote ID playfab/987654321 received local Platform ID Steam_123456789
	elif grep --quiet --regexp='PlayFab socket with remote ID .* received local Platform ID Steam_' <<< "${line}"; then
		local -r message=$(cut --delimiter=':' --fields=7 <<< "${line}")
		local -r id=$(cut --delimiter='_' --fields=2 <<< "${message}")
		CONNECTING+=("${id}")

	# determine if character spawn is occuring after a new connection has been initiated
	elif [[ ! -z "${CONNECTING[0]}" ]] && grep --quiet --regexp='Got character ZDOID from' <<< "${line}"; then
		local -r message=$(cut --delimiter=':' --fields=7 <<< "${line}")
		local -r character=$(cut --delimiter=' ' --fields=6 <<< "${message}")

		# ignore character spawn if related to already connected player
		if [[ ! -z "${PLAYERS[${character}]}" ]]; then return; fi

		# assume next connecting player is associated with this first character spawn
		local -r id="${CONNECTING[0]}"

		# record connection as complete by removing connection reference and associating character to steamid
		CONNECTING=("${STEAMID[@]:1}") # remove first element
		PLAYERS["${character}"]="${id}"

		# announce connection status
		local -r player=$(property "player.${id}" "(SteamID ${id})")
		message "${player} connected as ${character}"
		status $(( COUNT + 1 ))

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
		status $(( COUNT - 1 ))

	elif grep --quiet --regexp='Stopping valheim' <<< "${line}"; then
		COUNT=0
		topic 'server offline'
		name 'valheim - offline'

	elif grep --quiet --regexp='Valheim version' <<< "${line}"; then
		local -r version=$(cut --delimiter=':' --fields=8 <<< "${line}")
		message "started v${version}"
		status 0

	elif grep --quiet --regexp='Connections' <<< "${line}"; then
		local -r message=$(cut --delimiter=':' --fields=7 <<< "${line}")
		local -r squeezed=$(tr --squeeze-repeats ' ' <<< "${message}")
		local -ri count=$(cut --delimiter=' ' --fields=3 <<< "${squeezed}")
		status $count

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
