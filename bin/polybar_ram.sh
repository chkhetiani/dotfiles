#!/usr/bin/env bash

THRESHOLD=75
RAM_USAGE=$(free | grep Mem | awk '{print int($3/$2 * 100)}')

if [ "$RAM_USAGE" -ge "$THRESHOLD" ]; then
    echo "%{F#f7768e}RAM ${RAM_USAGE}%%{F-}"
else
    echo "%{F#9ece6a}RAM %{F-}${RAM_USAGE}%"
fi

