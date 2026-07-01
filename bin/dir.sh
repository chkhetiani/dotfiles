#!/bin/bash

selected=$(
    fd --type d --hidden --exclude '.*' . /home/irakli \
    | sed 's|^/home/irakli/||' \
    | rofi -dmenu -i -p "dir" \
        -matching fuzzy \
        -sort \
        -sorting-method fzf
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
