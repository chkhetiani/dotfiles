#!/bin/bash

time="$1"
text="$2"

echo "notify-send --category reminder 'Reminder' '$text'" | at now + "$time"
