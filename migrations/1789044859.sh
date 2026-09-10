#!/usr/bin/env bash

# The polkit agent stopped drawing its dialog on Fedora 44: hyprland-qt-support's style
# plugin, built against an older Qt's private API, fails to load against Qt 6.11.2, so
# every polkit prompt -- KeePassXC's Unlock among them -- hangs with nothing on screen.
# config/systemd/user/hyprpolkitagent.service.d/qt-style.conf points the agent at a stock
# Qt style instead, but config/ is only copied on a fresh install.
#
# Copies that one drop-in and restarts the agent so the next prompt uses it. Safe to
# re-run: the copy overwrites itself and the restart only happens when the agent runs.

set -uo pipefail

SRC="${HOME}/.local/share/desktop/config/systemd/user/hyprpolkitagent.service.d/qt-style.conf"
DEST_DIR="${HOME}/.config/systemd/user/hyprpolkitagent.service.d"

install -D -m 0644 "$SRC" "${DEST_DIR}/qt-style.conf" || exit 1
echo "  installed ${DEST_DIR}/qt-style.conf"

systemctl --user daemon-reload
if systemctl --user is-active --quiet hyprpolkitagent.service; then
  systemctl --user restart hyprpolkitagent.service
  echo "  restarted hyprpolkitagent"
fi
