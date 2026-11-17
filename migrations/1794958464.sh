#!/usr/bin/env bash

# Tap-to-click at the login screen. SDDM draws it in Weston, which leaves a touchpad's
# taps off -- Hyprland turns them on -- so a tap on the login button did nothing and it
# looked as if the mouse could not click. install/login/sddm.sh installs these now; this
# is for machines set up before. Takes effect at the next login screen: SDDM is not
# restarted, since that would end the session this runs in.

set -uo pipefail

SRC="$HOME/.local/share/desktop/default/sddm"
sudo install -D -m 0644 "$SRC/weston.ini" /etc/sddm/weston.ini || exit 1
sudo install -D -m 0644 "$SRC/weston.conf" /etc/sddm.conf.d/weston.conf || exit 1
echo "  tap-to-click on at the login screen, from the next one"
