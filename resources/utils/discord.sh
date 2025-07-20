#!/bin/sh

. "${UTILS}/json.sh"

# DISCORD_TOKEN

readonly DISCORD_BASE='https://discord.com/api'
readonly DISCORD_RATE=1

DISCORD_LAST=0

discord_delay() {
	now=$(date +%s)
	since=$(( now - DISCORD_LAST ))
	if [ $since -lt $DISCORD_RATE ]; then
		echo 'delaying discord api call to avoid rate limiting'
		sleep $DISCORD_RATE
	fi
}

discord_api() {
	method="${1}"
	path="${2}"
	body="${3}"

	discord_delay

	echo '---'
	echo
	echo "api call: ${method} ${path}"
	echo "api body: ${body}"

	DISCORD_LAST=$(date +%s)
	curl --silent --show-error --dump-header - \
		--request "${method}" \
		--header "Authorization: Bot ${DISCORD_TOKEN}" \
		--header 'Content-type: application/json' \
		--data "${body}" \
		"${DISCORD_BASE}${path}"
}

discord_message() {
	channel="${1}"
	content="${2}"

	escaped=$(json_escape "${content}")
	body='{"content":"'"${escaped}"'"}'

	discord_api 'POST' "/channels/${channel}/messages" "${body}"
}

discord_topic() {
	channel="${1}"
	topic="${2}"

	escaped=$(json_escape "${topic}")
	body='{"topic":"'"${escaped}"'"}'

	discord_api 'PATCH' "/channels/${channel}" "${body}"
}

discord_name() {
	channel="${1}"
	name="${2}"

	escaped=$(json_escape "${name}")
	body='{"name":"'"${escaped}"'"}'

	discord_api 'PATCH' "/channels/${channel}" "${body}"
}
