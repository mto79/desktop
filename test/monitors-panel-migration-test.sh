#!/usr/bin/env bash
# The migration that moves the bar's monitor button onto the monitors panel.
#
# It edits a file people edit, so what matters is what it leaves alone: a button pointed
# somewhere else on purpose, every other module, and a config it already moved.
source "$(dirname "$0")/lib.sh"

require jq || finish

MIGRATION="$ROOT/migrations/1789723682.sh"
sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
mkdir -p "$sandbox/.config/desktop"
CONFIG="$sandbox/.config/desktop/shell.json"
migrate() { HOME="$sandbox" bash "$MIGRATION" >/dev/null; }
module() { jq -c '.. | objects | select(.id? == "monitors")' "$CONFIG"; }

shipped='{"bar":{"layout":{"center":[{"id":"clock"},{"id":"monitors","type":"command","onClick":"desktop-menu monitors"},{"id":"ai","panel":"ai","onClick":"x"}]}}}'

echo "$shipped" >"$CONFIG"
migrate
check "the shipped button is moved onto the panel, with the menu on right click" \
  test "$(module)" = '{"id":"monitors","type":"command","panel":"monitors","onRightClick":"desktop-menu monitors"}'
check "and nothing else in the file changes" \
  test "$(jq -c '.bar.layout.center[0,2]' "$CONFIG" | tr -d '\n')" = '{"id":"clock"}{"id":"ai","panel":"ai","onClick":"x"}'

before=$(cat "$CONFIG")
migrate
check "running it again changes nothing" test "$(cat "$CONFIG")" = "$before"

echo '{"bar":{"layout":{"center":[{"id":"monitors","type":"command","onClick":"my-own-script"}]}}}' >"$CONFIG"
migrate
check "a button pointed elsewhere on purpose is left alone" \
  test "$(module)" = '{"id":"monitors","type":"command","onClick":"my-own-script"}'

rm "$CONFIG"
check "no shell.json is not an error" migrate

finish
