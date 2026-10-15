#!/bin/bash

CAVA_BG="$HOME/.local/bin/cava-bg"

if pgrep -x "cava-bg" > /dev/null 2>&1; then
    "$CAVA_BG" off
    echo "Cava bg stopped"
else
    setsid "$CAVA_BG" on > /dev/null 2>&1 < /dev/null &
    sleep 0.5
    if pgrep -x "cava-bg" > /dev/null 2>&1; then
        echo "cava bg started"
    else
        echo "Failed to start cava-bg"
    fi
fi
