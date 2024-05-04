#!/bin/bash
#
selected=$(find /home/irakli -not -path '*/.*' -type d -printf '%P\n' | rofi -dmenu -sorting-method fzf -sort -i -p "dir")

if [ -n "$selected" ]; then
    thunar "/home/irakli/$selected"
fi
