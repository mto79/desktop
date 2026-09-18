#!/usr/bin/env bash

# The bar's monitor button opens the monitors panel now, with the old menu on right click.
# shell.json is copied to ~/.config once and never again, so a machine installed earlier
# keeps a button that opens the menu -- this moves it over.
#
# Only a module still set up the way it shipped is changed. One whose click was pointed
# somewhere else was pointed there on purpose, and is left alone.

CONFIG="$HOME/.config/desktop/shell.json"

if [[ ! -f $CONFIG ]]; then
  echo "  no shell.json; the built-in config already has the panel"
  exit 0
fi

if ! jq -e '[.. | objects | select(.id? == "monitors" and .onClick? == "desktop-menu monitors" and (has("panel") | not))] | length > 0' "$CONFIG" >/dev/null; then
  echo "  the monitors module is already on the panel, or was customised"
  exit 0
fi

tmp=$(mktemp)
jq '(.. | objects | select(.id? == "monitors" and .onClick? == "desktop-menu monitors" and (has("panel") | not)))
      |= (del(.onClick) + {panel: "monitors", onRightClick: "desktop-menu monitors"})' "$CONFIG" >"$tmp" &&
  mv "$tmp" "$CONFIG" || {
  rm -f "$tmp"
  exit 1
}
echo "  the monitor button now opens the monitors panel"
