#!/usr/bin/env bash
# Which layout a desk gets, decided without a compositor.
#
# Two failures worth guarding. A layout that ends on a test returns that test's status,
# so `home` reported itself unavailable whenever the portrait screen was absent -- the
# ultrawide alone, the whole point of the desk, was filtered out of the SUPER+M menu.
# And now that desktop-monitors-watch calls this on every plug and unplug, applying a
# layout that is already in force has to be a no-op: applying one disables the screens
# it leaves out, which is itself a monitor event, which would apply it again.
source "$(dirname "$0")/lib.sh"

require jq || finish

SWITCH="$ROOT/bin/desktop-cmd-monitors-switch"
WATCH="$ROOT/bin/desktop-monitors-watch"

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
stubs="$sandbox/bin"
mkdir -p "$stubs" "$sandbox/.config/hypr"

# hyprctl is the only thing the script learns about the world from, so a fixture file
# stands in for a desk. reload and the rest are noise here and answer with nothing.
cat >"$stubs/hyprctl" <<'STUB'
#!/usr/bin/env bash
[[ "$*" == *monitors* ]] && cat "$MONITORS_FIXTURE"
exit 0
STUB
for noop in desktop-workspace-pin notify-send; do
  printf '#!/usr/bin/env bash\nexit 0\n' >"$stubs/$noop"
done
chmod +x "$stubs"/*

# A screen as hyprctl reports it. The model is what layouts match on.
screen() {
  printf '{"name":"%s","model":"%s","width":%s,"height":%s,"disabled":false}' \
    "$1" "$2" "${3:-1920}" "${4:-1080}"
}
desk() {
  local out="$sandbox/monitors.json" first=1 arg
  printf '[' >"$out"
  for arg in "$@"; do
    ((first)) || printf ',' >>"$out"
    first=0
    printf '%s' "$arg" >>"$out"
  done
  printf ']' >>"$out"
  echo "$out"
}

LAPTOP=$(screen eDP-1 0x4196)
ULTRAWIDE=$(screen DP-8 LS34A650U)
PORTRAIT=$(screen DP-9 "LG Ultra HD")
DOCK=$(screen DP-6 "HP P34hc G4")

layouts_for() {
  MONITORS_FIXTURE="$(desk "$@")" HOME="$sandbox" PATH="$stubs:$PATH" \
    bash "$SWITCH" --list
}

check "the laptop on its own offers only laptop" \
  test "$(layouts_for "$LAPTOP")" = "laptop"

# The regression: this used to print "laptop" alone.
check "the ultrawide without the portrait screen still offers home" \
  test "$(layouts_for "$LAPTOP" "$ULTRAWIDE")" = "home
laptop"

check "the portrait screen without the ultrawide offers home" \
  test "$(layouts_for "$LAPTOP" "$PORTRAIT")" = "home
laptop"

check "the whole home desk offers home" \
  test "$(layouts_for "$LAPTOP" "$ULTRAWIDE" "$PORTRAIT")" = "home
laptop"

check "the work dock offers work" \
  test "$(layouts_for "$LAPTOP" "$DOCK")" = "work
laptop"

# Applying, rather than only listing. A home desk missing its ultrawide should light the
# portrait screen where it belongs, not disable it.
CONF="$sandbox/.config/hypr/monitors.conf"
MONITORS_FIXTURE="$(desk "$LAPTOP" "$PORTRAIT")" HOME="$sandbox" PATH="$stubs:$PATH" \
  bash "$SWITCH" >/dev/null

check "the applied layout is home" grep -qx "# layout: home" "$CONF"
check "the portrait screen is placed, not disabled" \
  grep -qx "monitor=DP-9, 3840x2160@60, 0x0, 1, transform, 1" "$CONF"
check "no screen on the desk is disabled" test ! -s <(grep 'disable' "$CONF")

# Nothing changed, so the second run must leave the file alone. The header carries the
# proof: the comparison reads only the monitor lines, so a sentinel there survives
# exactly as long as the file is not rewritten.
sed -i 's/^# Generated on .*/# Generated on SENTINEL/' "$CONF"
MONITORS_FIXTURE="$(desk "$LAPTOP" "$PORTRAIT")" HOME="$sandbox" PATH="$stubs:$PATH" \
  bash "$SWITCH" >/dev/null
check "applying a layout already in force rewrites nothing" \
  grep -qx "# Generated on SENTINEL" "$CONF"

# What the bar shows for all this. The module is a command widget, so its whole
# contract is one line of JSON -- an unparseable line renders as literal text across the
# middle of the bar rather than as an error anybody would notice.
STATUS="$ROOT/bin/desktop-status-monitors"
status_json() {
  MONITORS_FIXTURE="$(desk "$LAPTOP" "$PORTRAIT")" HOME="$1" PATH="$ROOT/bin:$stubs:$PATH" \
    bash "$STATUS"
}

reported=$(status_json "$sandbox")
if jq -e . >/dev/null 2>&1 <<<"$reported"; then
  pass "the bar module prints parseable JSON"
else
  fail "the bar module prints parseable JSON" "$reported"
fi
# The module is the icon alone. The layout travels in `class`, which colours it, and in
# the tooltip -- a label saying "home" in the middle of the bar is a word describing
# something that has not changed since Monday.
check "the bar module carries the layout in force" \
  test "$(jq -r .class <<<"$reported")" = "home"
check "the bar module shows no label beside its icon" \
  test "$(jq -r .text <<<"$reported")" = ""

# A desk that has never had a layout written -- a fresh install -- still has to render:
# the module is what opens the menu that would fix it.
empty=$(mktemp -d)
trap 'rm -rf "$sandbox" "$empty"' EXIT
reported=$(status_json "$empty")
check "an unwritten layout reports itself rather than rendering nothing" \
  test "$(jq -r .class <<<"$reported")" = "unknown"

# And the watcher on top of it: a burst of events is one apply, not one apply per screen.
require python3 || finish

log="$sandbox/applied"
cat >"$stubs/desktop-cmd-monitors-switch" <<STUB
#!/usr/bin/env bash
echo applied >>"$log"
STUB
chmod +x "$stubs/desktop-cmd-monitors-switch"

sock="$sandbox/events.sock"
ready="$sandbox/ready"
python3 - "$sock" "$ready" <<'PY' &
import os, socket, sys, time
path, ready = sys.argv[1], sys.argv[2]
server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
server.bind(path)
server.listen(1)
open(ready, "w").close()
conn, _ = server.accept()
# A dock brings its screens up together; the watcher should coalesce them.
conn.sendall(b"monitoradded>>DP-8\n")
time.sleep(0.05)
conn.sendall(b"monitoradded>>DP-9\n")
time.sleep(1.5)
conn.close()
PY
server=$!

for _ in $(seq 100); do [[ -e $ready ]] && break; sleep 0.02; done
DESKTOP_HYPR_EVENT_SOCKET="$sock" PATH="$stubs:$PATH" timeout 6 python3 "$WATCH" >/dev/null 2>&1
wait "$server" 2>/dev/null || true

applied=$(wc -l <"$log" 2>/dev/null || echo 0)
if ((applied == 2)); then
  pass "the watcher applies once at startup and once per burst of events"
else
  fail "the watcher applies once at startup and once per burst of events" \
    "applied $applied time(s), expected 2 -- one at startup, one after the burst settled"
fi
finish
