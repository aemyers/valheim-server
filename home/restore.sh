#!/bin/bash

WORLDS=/home/{ACCOUNT}/.config/unity3d/IronGate/Valheim/worlds

tar --extract --verbose --file="$1" --directory="$WORLDS"
