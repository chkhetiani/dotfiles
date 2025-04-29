#!/bin/sh 

DIR="/tmp/c.png"

import -window root -crop "$(slop --tolerance=0 || exit 0)" "$DIR"
HEX=$(magick "$DIR" -scale 1x1\! -format "#%[hex:p{0,0}]" info:)

echo "${HEX}" | xclip -sel clip
notify-send -i "$DIR" "$HEX"
