#!/bin/bash

WORLDS={RESOURCES}/save/worlds

tar --extract --verbose --file="$1" --directory="$WORLDS"
