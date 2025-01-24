#!/bin/bash

# validate
if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <time> <message>"
    echo "Example: $0 12m 'Check the oven'"
    exit 1
fi

# Extract time and message
time=$1
message=$2

# Validate the time format
if [[ ! $time =~ ^[0-9]+[mh]$ ]]; then
    echo "Invalid time format. Use numbers followed by 'm' (minutes) or 'h' (hours)."
    exit 1
fi

# Convert time to seconds
if [[ $time == *m ]]; then
    seconds=$(( ${time%m} * 60 ))
elif [[ $time == *h ]]; then
    seconds=$(( ${time%h} * 3600 ))
fi

# Set the reminder
sleep "$seconds" && notify-send "$message" &
echo "Reminder set for $time: \"$message\""

