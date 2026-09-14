#!/usr/bin/env bash
# The idle cascade: screensaver, then lock, then the screen off.
#
# The order is the whole point. The screensaver listener is guarded by `pidof hyprlock`,
# so it does nothing once the session is locked -- which means a screensaver timeout at
# or past the lock's does not merely fire late, it never fires at all. Nudging one of the
# three timeouts without the others is an easy way to switch the screensaver off by
# accident and never notice.
source "$(dirname "$0")/lib.sh"

CONF="$ROOT/config/hypr/hypridle.conf"

# Each listener's timeout, in the order the file declares them, paired with what it runs.
mapfile -t timeouts < <(grep -oP '^\s*timeout = \K[0-9]+' "$CONF")
# Two ways to read this file wrong, both of which quietly return the wrong thing rather
# than failing: `on-timeout = ...` contains "timeout =" as well, so the match must be
# anchored, and `general` at the top already mentions lock-session in before_sleep_cmd,
# so a command only counts once some listener's timeout has been seen.
timeout_before() {
  awk -v want="$1" '/^[[:space:]]*timeout = /{t=$3} t != "" && $0 ~ want {print t; exit}' "$CONF"
}
screensaver=$(timeout_before "desktop-launch-screensaver")
lock=$(timeout_before "lock-session")
dpms=$(timeout_before "dpms off")

check "every listener declares a timeout" test "${#timeouts[@]}" = 3

if [[ -n $screensaver && -n $lock && -n $dpms ]]; then
  pass "the three listeners are all present"
else
  fail "the three listeners are all present" "screensaver=$screensaver lock=$lock dpms=$dpms"
fi

check "the screensaver comes before the lock, or it never runs at all" \
  test "$screensaver" -lt "$lock"
check "the screen goes off no earlier than the lock" test "$dpms" -ge "$lock"

# A lock that never arrives is a different kind of mistake, and one nobody notices until
# the laptop is left somewhere.
check "the session still locks itself within the hour" test "$lock" -le 3600

finish
