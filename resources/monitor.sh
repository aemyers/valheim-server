#!/bin/bash

set -o errexit
set -o pipefail

declare -r PROPERTIES='monitor.properties'
declare PLAYER=''

value() {
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

notify() {
	local -r content="${1}"

	local -r escaped=$(sed 's/"/\\"/g' <<< "${content}")

	curl --silent --show-error \
		--request POST \
		--header 'Content-type: application/json' \
		--data '{"content":"'"${escaped}"'"}' \
		"${HOOK}"
}

parse() {
	local -r line="${1}"

	if grep --quiet --regexp='Got connection SteamID' <<< "${line}"; then
		local -r message=$(cut --delimiter=':' --fields=7 <<< "${line}")
		local -r id=$(cut --delimiter=' ' --fields=5 <<< "${message}")
		PLAYER=$(value "player.${id}" "(SteamID ${id})")

	elif [[ "${PLAYER}" != '' ]] && grep --quiet --regexp='Got character ZDOID from' <<< "${line}"; then
		local -r message=$(cut --delimiter=':' --fields=7 <<< "${line}")
		local -r character=$(cut --delimiter=' ' --fields=6 <<< "${message}")
		notify "${PLAYER} connected as ${character}"
		PLAYER=''

	elif grep --quiet --regexp='Random event set' <<< "${line}"; then
		local -r event=$(cut --delimiter=':' --fields=8 <<< "${line}")
		local -r description=$(value "event.${event}")
		notify "random event started: \"${description}\" (${event})"

	fi
}

main() {
	declare -r HOOK=$(value "hook")
	local -r service=$(value "service")

	while true; do # until killed

		journalctl --unit="${service}" --lines=0 --follow \
			| while read -r line; do
				parse "${line}"
			done

		echo "exit code: $?"

	done
}

main "${@}"
