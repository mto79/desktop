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
# HOME as well: the script also links ~/.mozilla, and a test must not do that to the machine
# it runs on.
run() { HOME="$sandbox/home" XDG_CONFIG_HOME="$sandbox/home/.config" RHTLC_SETTINGS="$conf" bash "$SCRIPT" >/dev/null; }
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

# --- where Firefox keeps its profiles
# rhtlc looks in ~/.mozilla/firefox; Fedora's Firefox is in ~/.config/mozilla.
rm -rf "$sandbox/home"
moz() { HOME="$sandbox/home" RHTLC_SETTINGS="$conf" RHTLC_MOZILLA="$sandbox/home/.mozilla" RHTLC_MOZILLA_XDG="$sandbox/home/.config/mozilla" bash "$SCRIPT" >/dev/null; }
mkdir -p "$sandbox/home/.config/mozilla/firefox"
echo "[Profile0]" >"$sandbox/home/.config/mozilla/firefox/profiles.ini"
moz
check "Firefox's profiles are found where rhtlc looks for them" \
  test -f "$sandbox/home/.mozilla/firefox/profiles.ini"
check "as a link, not a second copy" test -L "$sandbox/home/.mozilla"
moz
check "a second run leaves the link as it is" \
  test "$(readlink "$sandbox/home/.mozilla")" = "$sandbox/home/.config/mozilla"

rm "$sandbox/home/.mozilla" && mkdir -p "$sandbox/home/.mozilla/firefox" && touch "$sandbox/home/.mozilla/firefox/mine"
moz
check "a ~/.mozilla that is already there is somebody's data, and is left" \
  test -f "$sandbox/home/.mozilla/firefox/mine" -a ! -L "$sandbox/home/.mozilla"

rm -rf "$sandbox/home" && mkdir -p "$sandbox/home"
moz
check "before Firefox has ever run, the link still leads somewhere" test -d "$sandbox/home/.mozilla/"

check "the install runs it" grep -qxF 'source "$DESKTOP_INSTALL/config/rhtlc.sh"' "$ROOT/install/config/all.sh"
check "the package it configures is installed" grep -qxF rhtlc "$ROOT/install/desktop-base.packages"
check "from a repository that is enabled" grep -q '"tmichett/RHTLC"' "$ROOT/install/preflight/copr.sh"

finish
