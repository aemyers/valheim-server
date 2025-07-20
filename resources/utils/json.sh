#!/bin/sh

json_escape() {
	value="${1}"

	replaced=${value//\\/\\\\}       # backslash
	replaced=${replaced//\"/\\\"}    # double quote
	replaced=${replaced//\//\\\/}    # forward slash
	replaced=${replaced//$'\t'/\\\t} # tab
	replaced=${replaced//$'\n'/\\\n} # newline
	replaced=${replaced//$'\r'/\\\r} # carriage return
	replaced=${replaced//$'\f'/\\\f} # form feed
	replaced=${replaced//$'\b'/\\\b} # backspace

	echo -n "${replaced}"
}
