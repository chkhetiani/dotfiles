#!/bin/bash
#
selected=$(find /home/irakli -not -path '*/.*' -type d -printf '%P\n' | rofi -dmenu -sorting-method fzf -sort -i -p "dir")

if [ -n "$selected" ]; then
    alacritty --working-directory "/home/irakli/$selected"
fi
