#!/usr/bin/env bash

# The tasks count comes off the bar, to make room for the headset's battery beside the
# Bluetooth icon. shell.json is copied to ~/.config once, so a machine installed earlier
# loses it here -- and only the module as it was shipped: one pointed at something else is
# someone's own. The panel keeps its key, SUPER+D then its letter.
CONFIG="$HOME/.config/desktop/shell.json"
SHIPPED='select(.id? == "tasks" and .type? == "command" and .exec? == "desktop-worktree tasks --bar")'
if [[ -f $CONFIG ]] && jq -e "[.bar.layout[][] | $SHIPPED] | length > 0" "$CONFIG" >/dev/null; then
  tmp=$(mktemp)
  jq "del(.bar.layout[][] | $SHIPPED)" "$CONFIG" >"$tmp" &&
    mv "$tmp" "$CONFIG" && echo "  the tasks count is off the bar"
  rm -f "$tmp"
fi
