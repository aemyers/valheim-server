#!/bin/sh

properties_read() {
	file="${1}"
	key="${2}"

	entry=$(grep --regexp="^${key}=" "${file}")
	if [ "${entry}" = '' ]; then return; fi
	cut --delimiter='=' --fields='2-' <<< "${entry}"
}
