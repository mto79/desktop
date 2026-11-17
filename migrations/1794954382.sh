#!/usr/bin/env bash

# The pipelines' timer and their mark on the bar, on machines installed before either
# existed. config/ is copied at install only, so the units are copied here; on a fresh
# machine install/config/pipelines.sh enables the timer.

SRC="$HOME/.local/share/desktop/config/systemd/user"
DEST="$HOME/.config/systemd/user"
mkdir -p "$DEST"
cp "$SRC/desktop-pipelines.service" "$SRC/desktop-pipelines.timer" "$DEST/"
systemctl --user daemon-reload
systemctl --user enable --now desktop-pipelines.timer
echo "  your merge requests' pipelines are asked every minute"

# The mark, beside the security shield. shell.json is copied once, so an existing one gets
# the entry here -- unless it has one already, or has no shield to sit beside, in which
# case the layout is someone's own and is left alone.
CONFIG="$HOME/.config/desktop/shell.json"
if [[ -f $CONFIG ]] && ! jq -e '[.. | objects | select(.id? == "pipelines")] | length > 0' "$CONFIG" >/dev/null; then
  if jq -e '[.. | arrays | select(any(.[]; type == "object" and .id? == "security"))] | length > 0' "$CONFIG" >/dev/null; then
    tmp=$(mktemp)
    jq '(.. | arrays | select(any(.[]; type == "object" and .id? == "security"))) |=
          (map(if type == "object" and .id? == "security" then ., {id: "pipelines"} else . end))' "$CONFIG" >"$tmp" &&
      mv "$tmp" "$CONFIG" && echo "  the pipelines' mark is on the bar, beside security"
  fi
fi
