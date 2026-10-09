#!/usr/bin/env bash
# The power menu: six things, three of which cannot be undone.
#
# What each does lives in desktop-power, so the shell's menu and desktop-menu's cannot
# drift apart; every command it would run is a stub here. The menu itself is checked for
# the two things that keep it from doing one of them by accident -- asking twice, and not
# listening to the keyboard the instant it appears.
source "$(dirname "$0")/lib.sh"

POWER="$ROOT/bin/desktop-power"
MENU="$ROOT/shell/Power/PowerMenu.qml"
sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
stubs="$sandbox/stubs"
mkdir -p "$stubs"
for cmd in systemctl uwsm desktop-lock-screen desktop-launch-screensaver desktop-state; do
  printf '#!/usr/bin/env bash\necho "%s $*" >>"%s/calls"\n' "$cmd" "$sandbox" >"$stubs/$cmd"
done
chmod +x "$stubs"/*
run() { : >"$sandbox/calls"; PATH="$stubs:$PATH" bash "$POWER" "$@" 2>/dev/null; tr '\n' ';' <"$sandbox/calls"; }

check "lock locks" test "$(run lock)" = "desktop-lock-screen ;"
check "suspend suspends" test "$(run suspend)" = "systemctl suspend;"
check "screensaver starts it now" test "$(run screensaver)" = "desktop-launch-screensaver force;"
# The marks are what make the bar ask for a restart; left behind, it goes on asking for
# the one that has just happened.
check "reboot clears the restart-required marks first" \
  test "$(run reboot)" = "desktop-state clear re*-required;systemctl reboot;"
check "shutdown does too" test "$(run shutdown)" = "desktop-state clear re*-required;systemctl poweroff;"
check "leaving the session stops it through uwsm" \
  test "$(run exit)" = "desktop-state clear relaunch-required;uwsm stop;"
check "anything else does nothing at all" test -z "$(run restart)"

# --- one place
check "desktop-menu's System menu uses the same script" \
  test "$(grep -c 'desktop-power \(lock\|screensaver\|suspend\|exit\|reboot\|shutdown\) ;;' "$ROOT/bin/desktop-menu")" = 6
check "and no longer has commands of its own for them" \
  lacks 'systemctl \(reboot\|poweroff\|suspend\)' "$ROOT/bin/desktop-menu"
check "the shell's menu runs it as arguments, not through a shell" \
  grep -q 'execDetached(\["desktop-power", action.id\])' "$MENU"
for action in lock screensaver suspend exit reboot shutdown; do
  check "the menu offers $action" grep -q "id: \"$action\"" "$MENU"
done

# --- not by accident
# The three that cannot be undone say what a second press will do; the others have
# nothing to say, which is what makes them act on the first.
confirmed=$(grep -B4 'confirm: "Press again' "$MENU" | grep -oP 'id: "\K[a-z]+' | tr '\n' ' ')
check "ending the session, rebooting and switching off are asked for twice" \
  test "$confirmed" = "exit reboot shutdown "
check "moving to another tile disarms the one that was pressed" \
  test -n "$(sed -n '/function move(delta)/,/^  }/p' "$MENU" | grep 'armed = -1')"
# It takes the keyboard the moment it opens, and whatever was being typed elsewhere lands
# in it. That locked the screen the first time it was opened while someone was typing.
check "keys are ignored until it has been on screen for a moment" \
  test -n "$(sed -n '/Keys.onPressed/,/^        }/p' "$MENU" | grep -A2 'if (!root.ready)' | grep 'return')"
check "and every opening starts not ready" \
  test -n "$(sed -n '/function show()/,/^  }/p' "$MENU" | grep 'ready = false')"
check "Escape closes it regardless" grep -q 'Keys.onEscapePressed: root.hide()' "$MENU"

# --- wired in
check "the power menu is part of the shell" grep -q '^  PowerMenu {' "$ROOT/shell/shell.qml"
check "SUPER + ESCAPE opens it, and the old menu if the shell is not there" \
  grep -qx 'bindd = SUPER, ESCAPE, Power menu, exec, desktop-shell shell togglePowerMenu >/dev/null 2>&1 || desktop-menu system' \
  "$ROOT/default/hypr/bindings/utilities.conf"
check "in the Lua bindings as well" \
  grep -q 'SUPER + ESCAPE.*togglePowerMenu >/dev/null 2>&1 || desktop-menu system' "$ROOT/default/hypr/bindings/utilities.lua"

finish
