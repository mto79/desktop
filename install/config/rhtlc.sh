#!/usr/bin/env bash

# Tell the Red Hat Training Lab Connector which terminal to open its SSH sessions in.
#
# rhtlc opens SSH and SSHuttle in a terminal window, and finds one by looking for the names
# it knows: gnome-terminal, konsole, kitty, xterm and a dozen more. Ghostty is the
# only terminal here and is not among them, so both buttons answered "no supported
# terminal emulator found". Its settings have an escape hatch for exactly that -- a
# command of your own, with {cmd} where the ssh goes.
#
# The file is rhtlc's, not ours: it writes it on first run, keeps the SSH user and key in
# it, and adds sections to it as versions go by. So nothing is copied over it. A file that
# is not there yet is started with this one section, which rhtlc keeps and fills in around
# (checked against 6.0.2); one that is there gets the line only if no terminal has been
# chosen in it already, by this script or by hand.
#
# --title because every Ghostty window has the same app id, and a title is the only thing
# a window rule could tell this one by.

RHTLC_SETTINGS="${RHTLC_SETTINGS:-$HOME/.rhtlc/settings.conf}"
RHTLC_TERMINAL='custom_command = ghostty --title=RHTLC -e {cmd}'

if [[ ! -f $RHTLC_SETTINGS ]]; then
  mkdir -p "$(dirname "$RHTLC_SETTINGS")"
  printf '[terminal]\n%s\n' "$RHTLC_TERMINAL" >"$RHTLC_SETTINGS"
  echo "rhtlc: SSH sessions will open in Ghostty"
elif grep -qE '^[[:space:]]*(custom_command|app)[[:space:]]*=[[:space:]]*[^[:space:]]' "$RHTLC_SETTINGS"; then
  echo "rhtlc: a terminal is already chosen in $RHTLC_SETTINGS; left as it is"
elif grep -qE '^#[[:space:]]*custom_command[[:space:]]*=[[:space:]]*$' "$RHTLC_SETTINGS"; then
  # The placeholder rhtlc's own template leaves, in the place its comments explain it.
  sed -i -E "0,/^#[[:space:]]*custom_command[[:space:]]*=[[:space:]]*\$/s||$RHTLC_TERMINAL|" "$RHTLC_SETTINGS"
  echo "rhtlc: SSH sessions will open in Ghostty"
elif grep -qxF '[terminal]' "$RHTLC_SETTINGS"; then
  sed -i "0,/^\[terminal\]\$/s||[terminal]\n$RHTLC_TERMINAL|" "$RHTLC_SETTINGS"
  echo "rhtlc: SSH sessions will open in Ghostty"
else
  printf '\n[terminal]\n%s\n' "$RHTLC_TERMINAL" >>"$RHTLC_SETTINGS"
  echo "rhtlc: SSH sessions will open in Ghostty"
fi

# And where Firefox keeps its profiles. rhtlc's Firefox button writes the lab's SOCKS proxy
# into a profile's user.js, and looks for profiles in ~/.mozilla/firefox -- or a Flatpak's
# or a Snap's -- and nowhere else. Fedora's Firefox has moved to ~/.config/mozilla, which
# rhtlc does not know, so the button answered "no Firefox profile found" on a machine with
# two of them.
#
# ~/.mozilla is made a link to the new place rather than the profiles moved back: Firefox
# uses ~/.mozilla whenever it exists, so it follows the link to the same files and sees no
# difference, and rhtlc finds what it is looking for. Only where there is no ~/.mozilla at
# all -- one that exists is somebody's data, or the old layout still in use, and is left.
RHTLC_MOZILLA="${RHTLC_MOZILLA:-$HOME/.mozilla}"
RHTLC_MOZILLA_XDG="${RHTLC_MOZILLA_XDG:-${XDG_CONFIG_HOME:-$HOME/.config}/mozilla}"

if [[ ! -e $RHTLC_MOZILLA && ! -L $RHTLC_MOZILLA ]]; then
  # Made if Firefox has not run yet, so the link never dangles and Firefox's first profile
  # lands where it would have anyway.
  mkdir -p "$RHTLC_MOZILLA_XDG"
  ln -s "$RHTLC_MOZILLA_XDG" "$RHTLC_MOZILLA"
  echo "rhtlc: Firefox profiles are reachable at $RHTLC_MOZILLA"
fi
