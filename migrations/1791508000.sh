#!/usr/bin/env bash

# Give a machine that is already installed its clipboard history.
#
# The history is cliphist behind desktop-clipboard: a clean install gets the package from
# desktop-base.packages and the watcher from Hyprland's autostart. Autostart only runs at
# login, so here the watcher is started as well, in the session that is already running.

if ! rpm -q cliphist >/dev/null 2>&1; then
  # --disablerepo because pgAdmin4's repo fails GPG verification, and one bad repo stops
  # a transaction that has nothing to do with it.
  sudo dnf install -y --disablerepo=pgAdmin4 cliphist || exit 1
  echo "  installed cliphist"
fi

if pgrep -f 'wl-paste .*desktop-clipboard store' >/dev/null 2>&1; then
  echo "  the clipboard watcher was already running"
elif hyprctl dispatch exec "uwsm app -- desktop-clipboard watch" >/dev/null 2>&1; then
  echo "  the clipboard watcher is running; SUPER + V shows the history"
else
  # No compositor to ask -- run from a console, say. It starts at the next login.
  echo "  the clipboard watcher starts at the next login"
fi
