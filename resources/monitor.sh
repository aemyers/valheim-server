#!/bin/bash

set -o errexit
set -o pipefail

declare -r PROPERTIES='monitor.properties'

value() {
	local -r file="${1}"
	local -r key="${2}"

	grep "^${key}=" "${file}" | cut --delimiter='=' --fields='2-'
}

notify() {
	local -r content="${1}"

	curl --silent --show-error \
		--request POST \
		--header 'Content-type: application/json' \
		--data '{"content":"'"${content}"'"}' \
		"${HOOK}"
}

parse() {
	local -r line="${1}"

	if grep --quiet --regexp='Got character ZDOID from' <<< "${line}"; then
		local -r message=$(cut --delimiter=':' --fields=7 <<< "${line}")
		local -r name=$(cut --delimiter=' ' --fields=6 <<< "${message}")
		notify "player connected: ${name}"

	elif grep --quiet --regexp='Random event set' <<< "${line}"; then
		local -r event=$(cut --delimiter=':' --fields=8 <<< "${line}")
		notify "random event: ${event}"

        fi
}

main() {
	declare -r HOOK=$(value "${PROPERTIES}" "hook")
	local -r service=$(value "${PROPERTIES}" "service")

	while true; do # until killed

		journalctl --unit="${service}" --lines=0 --follow \
			| while read -r line; do
				parse "${line}"
			done

		echo "exit code: $?"

	done
}

main "${@}"