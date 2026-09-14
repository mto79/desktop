#!/usr/bin/env bash
# Ducking whatever is playing while voxtype records, and -- the part that matters --
# giving it back.
#
# The volume must return to what it was, not to a fixed number, and it must return in
# every case the machine can end up in: the recording stopping, voxtype restarting under
# the watcher, voxtype not running at all. The duck follows voxtype's state rather than a
# keybinding because a Hyprland `bindr` on a chord dropped about one release in three,
# and the music stayed down with nothing left to bring it back.
source "$(dirname "$0")/lib.sh"

require jq || finish

DICTATE="$ROOT/bin/desktop-dictate"

sandbox=$(mktemp -d)
stubs="$sandbox/bin"
mkdir -p "$stubs" "$sandbox/run/desktop"
trap 'pkill -f "$DICTATE watch" 2>/dev/null; rm -rf "$sandbox"' EXIT

# wpctl reads and writes one number in a file, the way a sink would.
echo 0.70 >"$sandbox/volume"
cat >"$stubs/wpctl" <<'STUB'
#!/usr/bin/env bash
case "$1" in
get-volume) echo "Volume: $(cat "$VOLUME_FILE")" ;;
set-volume) printf '%s\n' "$3" >"$VOLUME_FILE" ;;
esac
STUB

# voxtype streams a status line whenever one is appended to the script file, and the
# stream ends when that file says so -- which is how a restarting daemon is played back.
cat >"$stubs/voxtype" <<'STUB'
#!/usr/bin/env bash
[[ $1 == status ]] || exit 0
tail -n +1 -f "$VOX_SCRIPT" 2>/dev/null | while IFS= read -r line; do
  [[ $line == END ]] && exit 0
  printf '{"class":"%s"}\n' "$line"
done
STUB
# setpriv is not available to a test that is not root; the watcher only wants the
# pdeathsig, so run the command straight through.
cat >"$stubs/setpriv" <<'STUB'
#!/usr/bin/env bash
shift 2  # --pdeathsig TERM
exec "$@"
STUB
chmod +x "$stubs"/*

: >"$sandbox/script"
XDG_RUNTIME_DIR="$sandbox/run" VOLUME_FILE="$sandbox/volume" VOX_SCRIPT="$sandbox/script" \
  PATH="$stubs:$PATH" bash "$DICTATE" watch &
watcher=$!

vol() { cat "$sandbox/volume"; }
say() { printf '%s\n' "$1" >>"$sandbox/script"; }
# Waits for a value rather than sleeping a fixed time: the watcher is pushed, so this is
# normally instant, and a test that sleeps "long enough" is a test that flakes.
settles_at() {
  local want="$1" i
  for ((i = 0; i < 100; i++)); do
    [[ $(vol) == "$want" ]] && return 0
    sleep 0.05
  done
  return 1
}

check "an idle daemon leaves the volume alone" test "$(vol)" = "0.70"

say recording
check "recording ducks the output, relative to where it was" settles_at 0.14
check "the volume it had is remembered" \
  test "$(cat "$sandbox/run/desktop/dictate-volume")" = "0.70"

# Transcribing is not recording: the mic is shut, so the music comes straight back
# rather than waiting out however long the model takes.
say transcribing
check "the music returns as soon as the mic closes" settles_at 0.70
check "nothing is left behind to restore twice" \
  test ! -f "$sandbox/run/desktop/dictate-volume"

say idle
check "idle changes nothing further" test "$(vol)" = "0.70"

# A second recording must save the real volume again, not the ducked one it would have
# seen had the first restore not happened.
say recording
check "a second recording ducks from the restored volume" settles_at 0.14
check "and remembers the real volume, not the ducked one" \
  test "$(cat "$sandbox/run/desktop/dictate-volume")" = "0.70"

# The daemon goes away mid-recording -- a restart, a crash, a `systemctl stop`. The
# stream ends with the music still down, and only the watcher can put it back.
say END
check "a daemon that dies mid-recording still gives the volume back" settles_at 0.70
check "and leaves no saved volume behind" \
  test ! -f "$sandbox/run/desktop/dictate-volume"

# It must also reconnect, or dictation is silent-ducked for the rest of the session.
: >"$sandbox/script"
say recording
check "the watcher reconnects to a daemon that came back" settles_at 0.14
say idle
check "and ducks and restores as before" settles_at 0.70

kill "$watcher" 2>/dev/null
check "an unknown argument is refused" \
  lacks . <<<"$(bash "$DICTATE" wibble 2>/dev/null || true)"

# The escape hatch, for a machine found quiet with no watcher running.
echo 0.70 >"$sandbox/run/desktop/dictate-volume"
echo 0.14 >"$sandbox/volume"
XDG_RUNTIME_DIR="$sandbox/run" VOLUME_FILE="$sandbox/volume" PATH="$stubs:$PATH" \
  bash "$DICTATE" restore
check "restore by hand puts it back" test "$(vol)" = "0.70"

finish
