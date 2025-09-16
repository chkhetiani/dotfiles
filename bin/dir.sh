#!/bin/bash
selected=$(
    find /home/irakli -not -path '*/.*' -type d -printf '%P\n' |
    rofi -dmenu -sorting-method fzf -sort -i -p "dir"
)
rofi_exit=$?

if [[ $rofi_exit -ne 0 ]]; then
    exit 0
fi

if [[ -z "$selected" ]]; then
    thunar "/home/irakli"
else
    thunar "/home/irakli/$selected"
fi
