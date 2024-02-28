#!/bin/sh 

TERM=xterm-256color
tmux new-session -s Booming-Games   -n random -d 'cd ~; zsh -i'
tmux new-window  -t Booming-Games:1 -n maven   'cd ~/Dev/prototypes; mvn install -f pom.xml; zsh -i'
tmux new-window  -t Booming-Games:2 -n nvim   'cd ~/Dev/prototypes; nvim; zsh -i'
tmux new-window  -t Booming-Games:3 -n git   'cd ~/Dev/prototypes; git status; zsh -i'
tmux new-window  -t Booming-Games:4 -n core   'cd ~/Dev/core3; nvim; zsh -i'
tmux new-window  -t Booming-Games:5 -n music   'cd ~/; ytfzf -m; zsh -i'

tmux select-window -t Booming-Games:1
tmux -2 attach-session -t Booming-Games
