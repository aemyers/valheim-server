#!/bin/bash

RESOURCES='{{ RESOURCES }}'
WORLDS="$RESOURCES/save/worlds_local"

tar --extract --verbose --file="$1" --directory="$WORLDS"
