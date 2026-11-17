#!/usr/bin/env bash

# desktop-cmd-screenrecord: stopping a recording says which file it saved, with buttons
# to open it or find it in its folder, and the stop does not wait for the toast. Run
# against stand-ins: nothing here records, kills a recorder or opens anything.

source "$(dirname "$0")/lib.sh"

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
stubs=$sandbox/bin
mkdir -p "$stubs" "$sandbox/videos"
# A recording is running, so a press is the stop.
printf '#!/usr/bin/env bash\ntrue\n' >"$stubs/pgrep"
printf '#!/usr/bin/env bash\ntrue\n' >"$stubs/pkill"
printf '#!/usr/bin/env bash\ntrue\n' >"$stubs/sleep"
# The toast records what it was asked to show and answers as a click on Open would,
# after a while, as a person would.
cat >"$stubs/notify-send" <<STUB
#!/usr/bin/env bash
printf '%s\n' "\$@" >"$sandbox/toast"
/usr/bin/sleep 0.5
echo open
STUB
printf '#!/usr/bin/env bash\necho "$*" >"%s/opened"\n' "$sandbox" >"$stubs/xdg-open"
chmod +x "$stubs"/*

: >"$sandbox/videos/screenrecording-2026-11-18_09-00-00.mp4"
: >"$sandbox/videos/screenrecording-2026-11-18_10-00-00.mp4"
touch -d '2026-11-18 09:00' "$sandbox/videos/screenrecording-2026-11-18_09-00-00.mp4"
touch -d '2026-11-18 10:00' "$sandbox/videos/screenrecording-2026-11-18_10-00-00.mp4"

stop() {
  HOME=$sandbox PATH="$stubs:$PATH" DESKTOP_SCREENRECORD_DIR="$sandbox/videos" \
    bash "$ROOT/bin/desktop-cmd-screenrecord" >/dev/null 2>&1
}

start=$(date +%s%N)
stop
took=$((($(date +%s%N) - start) / 1000000))
check "the stop returns without waiting for the toast (${took}ms)" test "$took" -lt 400

for _ in $(seq 30); do [[ -e $sandbox/opened ]] && break; /usr/bin/sleep 0.1; done
check "the toast names the newest recording" grep -qx "screenrecording-2026-11-18_10-00-00.mp4" "$sandbox/toast"
check "and offers to open it" grep -qx -- "--action=open=Open" "$sandbox/toast"
check "and to find it in its folder" grep -qx -- "--action=folder=Folder" "$sandbox/toast"
check "Open opens that recording" grep -qx "$sandbox/videos/screenrecording-2026-11-18_10-00-00.mp4" "$sandbox/opened"

# Nothing in the folder: a plain toast that says so, no buttons for a file that is not there.
rm -f "$sandbox"/videos/* "$sandbox/toast"
stop
check "a stop with nothing saved says so" grep -q "Nothing was saved" "$sandbox/toast"

finish
