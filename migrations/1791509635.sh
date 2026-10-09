#!/usr/bin/env bash

# Give a machine that is already installed the redrawn logo in its screensaver.
#
# The screensaver does not read logo.txt: branding.sh copies it once, at install, to
# ~/.config/desktop/branding/screensaver.txt so that it can be edited from the menu. That
# makes the copy the user's, so it is replaced only while it is still byte for byte the
# logo that was shipped before -- anything else is somebody's own drawing and stays.

old_logo=55d582674a2c7b1619ee1d426fffe0695ab4dc41deba9e144f8f98f0b62e6294
logo=~/.local/share/desktop/logo.txt
screensaver=~/.config/desktop/branding/screensaver.txt

if [[ ! -f $screensaver ]]; then
  echo "  no screensaver branding to update"
elif cmp -s "$logo" "$screensaver"; then
  echo "  the screensaver already shows the new logo"
elif [[ $(sha256sum <"$screensaver" | cut -d' ' -f1) == "$old_logo" ]]; then
  cp "$logo" "$screensaver" || exit 1
  echo "  the screensaver shows the new logo"
else
  echo "  the screensaver branding was edited by hand; left alone"
fi
