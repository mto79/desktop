#!/usr/bin/env bash

# The right of the bar becomes five pills -- connection, sound, agents, alerts, system --
# that show what matters at rest and open on hover (shell/Bar/widgets/Group.qml). Done
# only to a layout still exactly as it was shipped; each widget keeps its own settings,
# taken from the file itself. A layout arranged by hand is left alone.
CONFIG="$HOME/.config/desktop/shell.json"
[[ -f $CONFIG ]] || exit 0

shipped='["tray","spacer","bluetooth","vpn","network","spacer","audio","microphone","spacer","ai","camera","spacer","security","backup","spacer","disk","memory","cpu","battery"]'
jq -e --argjson shipped "$shipped" '[.bar.layout.right[]?.id] == $shipped' "$CONFIG" >/dev/null 2>&1 || exit 0

tmp=$(mktemp)
jq '
  def byid($i): [.bar.layout.right[] | select(.id == $i)][0];
  .bar.layout.right = [
    byid("tray"),
    {"id": "spacer", "width": 6},
    {"id": "connection", "type": "group", "show": ["network"], "widgets": [byid("bluetooth"), byid("vpn"), byid("network")]},
    {"id": "spacer", "width": 6},
    {"id": "sound", "type": "group", "widgets": [byid("audio"), byid("microphone")]},
    {"id": "spacer", "width": 6},
    {"id": "agents", "type": "group", "widgets": [byid("ai"), byid("camera")]},
    {"id": "spacer", "width": 6},
    {"id": "alerts", "type": "group", "widgets": [byid("security"), byid("backup")]},
    {"id": "spacer", "width": 6},
    {"id": "system", "type": "group", "show": ["cpu", "battery"], "widgets": [byid("disk"), byid("memory"), byid("cpu"), byid("battery")]}
  ]' "$CONFIG" >"$tmp" && mv "$tmp" "$CONFIG" && echo "  the bar's right side is grouped into pills"
rm -f "$tmp"
exit 0
