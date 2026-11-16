#!/usr/bin/env bash

# The bar's memory widget keeps its number when the bar is short of room, as the CPU keeps
# its percentage: on the laptop's screen alone it was the first to show a bare glyph. A
# memory widget that already says anything about keepText is left as it is.
CONFIG="$HOME/.config/desktop/shell.json"
[[ -f $CONFIG ]] || exit 0
jq -e '[.. | objects | select(.id? == "memory" and (has("keepText") | not))] | length > 0' "$CONFIG" >/dev/null 2>&1 || exit 0
tmp=$(mktemp)
jq '(.. | objects | select(.id? == "memory" and (has("keepText") | not))) |= (.keepText = true)' "$CONFIG" >"$tmp" &&
  mv "$tmp" "$CONFIG" && echo "  the bar's memory widget keeps its number"
rm -f "$tmp"
exit 0
