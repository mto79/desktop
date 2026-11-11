#!/usr/bin/env bash

# mpv decodes video on a GPU (config/mpv/mpv.conf). Copied only when there is no mpv.conf
# yet: one written by hand is kept.
[[ -e ~/.config/mpv/mpv.conf ]] && exit 0
mkdir -p ~/.config/mpv
cp ~/.local/share/desktop/config/mpv/mpv.conf ~/.config/mpv/mpv.conf
