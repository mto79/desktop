#!/usr/bin/env bash

# The security check's timer and the shield on the bar, on machines installed before
# either existed. config/ is copied at install only, so the timer's units are copied here;
# on a fresh machine install/config/security.sh enables it.

SRC="$HOME/.local/share/desktop/config/systemd/user"
DEST="$HOME/.config/systemd/user"
mkdir -p "$DEST"
cp "$SRC/desktop-security-check.service" "$SRC/desktop-security-check.timer" "$DEST/"
systemctl --user daemon-reload
systemctl --user enable --now desktop-security-check.timer
echo "  the security check runs every fifteen minutes"

# And the shield on the bar, beside the backup icon. shell.json is copied once, so an
# existing one gets the entry here -- unless it already has one, or has no backup icon
# to sit beside, in which case the layout is someone's own and is left alone.
CONFIG="$HOME/.config/desktop/shell.json"
if [[ -f $CONFIG ]] && ! jq -e '[.. | objects | select(.id? == "security")] | length > 0' "$CONFIG" >/dev/null; then
  if jq -e '[.. | arrays | select(any(.[]; type == "object" and .id? == "backup"))] | length > 0' "$CONFIG" >/dev/null; then
    tmp=$(mktemp)
    jq '(.. | arrays | select(any(.[]; type == "object" and .id? == "backup"))) |=
          (map(if type == "object" and .id? == "backup" then {id: "security"}, . else . end))' "$CONFIG" >"$tmp" &&
      mv "$tmp" "$CONFIG" && echo "  the security shield is on the bar, beside backup"
  fi
fi
