#!/usr/bin/env zsh

# increment the limit of the number of file descriptors in 1 process
ulimit -n 1024

# It will disable the above behavior and free Ctrl-S and Ctrl-Q for use in terminal apps!
stty -ixon -ixoff

# enable emacs keymap to use ^A ^E
bindkey -e
