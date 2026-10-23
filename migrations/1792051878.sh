#!/usr/bin/env bash

# Take libcamera out of WirePlumber, so a stuck built-in camera cannot take every audio
# device down with it. Takes effect on the next login or `systemctl --user restart
# wireplumber`; it is not restarted here, which would drop any call in progress.

mkdir -p ~/.config/wireplumber/wireplumber.conf.d
cp ~/.local/share/desktop/config/wireplumber/wireplumber.conf.d/50-no-libcamera.conf \
  ~/.config/wireplumber/wireplumber.conf.d/
echo "  WirePlumber no longer loads libcamera; restart it or log in again to apply"
