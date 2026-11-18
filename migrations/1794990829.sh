#!/usr/bin/env bash

# The printers' timer and their mark on the bar, on machines installed before either
# existed. config/ is copied at install only, so the units are copied here; on a fresh
# machine install/config/printers.sh enables the timer.

SRC="$HOME/.local/share/desktop/config/systemd/user"
DEST="$HOME/.config/systemd/user"
mkdir -p "$DEST"
cp "$SRC/desktop-printers.service" "$SRC/desktop-printers.timer" "$DEST/"
systemctl --user daemon-reload
systemctl --user enable --now desktop-printers.timer
echo "  the printers within reach are asked every two minutes"

# The mark, beside the pipelines'. shell.json is copied once, so an existing one gets the
# entry here -- unless it has one already, or has no pipelines mark to sit beside, in which
# case the layout is someone's own and is left alone.
CONFIG="$HOME/.config/desktop/shell.json"
if [[ -f $CONFIG ]] && ! jq -e '[.. | objects | select(.id? == "printers")] | length > 0' "$CONFIG" >/dev/null; then
  if jq -e '[.. | arrays | select(any(.[]; type == "object" and .id? == "pipelines"))] | length > 0' "$CONFIG" >/dev/null; then
    tmp=$(mktemp)
    jq '(.. | arrays | select(any(.[]; type == "object" and .id? == "pipelines"))) |=
          (map(if type == "object" and .id? == "pipelines" then ., {id: "printers"} else . end))' "$CONFIG" >"$tmp" &&
      mv "$tmp" "$CONFIG" && echo "  the printers' mark is on the bar, beside the pipelines'"
  fi
fi
