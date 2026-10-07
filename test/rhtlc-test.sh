#!/usr/bin/env bash
# rhtlc opens SSH in a terminal it has to find, and does not know Ghostty. The install sets
# its escape hatch -- in a file that belongs to rhtlc, holds the SSH user and key, and must
# not be overwritten or have a choice made by hand undone.
source "$(dirname "$0")/lib.sh"

SCRIPT="$ROOT/install/config/rhtlc.sh"
WANT='custom_command = ghostty --title=RHTLC -e {cmd}'
sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
conf="$sandbox/.rhtlc/settings.conf"
run() { RHTLC_SETTINGS="$conf" bash "$SCRIPT" >/dev/null; }
chosen() { grep -cE '^(custom_command|app) *= *[^ ]' "$conf"; }

run
check "with no settings yet, a file is started with the terminal in it" grep -qxF "$WANT" "$conf"
check "under the section rhtlc reads it from" test "$(head -1 "$conf")" = "[terminal]"

# What rhtlc 6.0.2 writes on first run, cut down to the lines that matter.
template() {
  mkdir -p "$(dirname "$conf")"
  cat >"$conf" <<'CONF'
[ssh]
user = instructor
# identity_file = ~/.ssh/id_rsa

[terminal]
# app = ptyxis
# Example: custom_command = my-terminal --tab -e {cmd}
#
# custom_command =
CONF
}

template
run
check "in rhtlc's own file, the placeholder is filled in" grep -qxF "$WANT" "$conf"
check "and nothing else in it is touched" grep -qxF 'user = instructor' "$conf"
check "the example in the comments is still a comment" \
  grep -qxF '# Example: custom_command = my-terminal --tab -e {cmd}' "$conf"
before=$(cat "$conf")
run
check "a second run changes nothing" test "$(cat "$conf")" = "$before"
check "and does not choose twice" test "$(chosen)" = 1

template
sed -i 's/^# app = ptyxis$/app = kitty/' "$conf"
run
check "a terminal chosen by hand is left alone" lacks 'ghostty' "$conf"

template
sed -i 's/^# custom_command =$/custom_command = foot -e {cmd}/' "$conf"
run
check "and so is a command of your own" grep -qxF 'custom_command = foot -e {cmd}' "$conf"

printf '[ssh]\nuser = student\n\n[terminal]\n' >"$conf"
run
check "a section with no placeholder gets the line" grep -qxF "$WANT" "$conf"
check "inside that section" test "$(grep -A1 -xF '[terminal]' "$conf" | tail -1)" = "$WANT"

printf '[ssh]\nuser = student\n' >"$conf"
run
check "a file from before rhtlc had the section gets both" \
  test "$(tail -2 "$conf" | tr '\n' '|')" = "[terminal]|$WANT|"
check "after what was there" test "$(sed -n 2p "$conf")" = "user = student"

check "the install runs it" grep -qxF 'source "$DESKTOP_INSTALL/config/rhtlc.sh"' "$ROOT/install/config/all.sh"
check "the package it configures is installed" grep -qxF rhtlc "$ROOT/install/desktop-base.packages"
check "from a repository that is enabled" grep -q '"tmichett/RHTLC"' "$ROOT/install/preflight/copr.sh"

finish
