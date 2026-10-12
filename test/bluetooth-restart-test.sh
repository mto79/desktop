#!/usr/bin/env bash
# The drop-in that brings a crashed bluetoothd back, written into a sandbox instead of
# /etc. sudo and systemctl are stubs: what is checked is the file, and that a second run
# -- the migration after the installer, or the migration retried -- leaves it alone.
source "$(dirname "$0")/lib.sh"

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
mkdir -p "$sandbox/bin" "$sandbox/etc"

printf '#!/usr/bin/env bash\necho "sudo $*" >>"%s/calls"\nexec "$@"\n' "$sandbox" >"$sandbox/bin/sudo"
# `systemctl cat` answers for whether the unit exists; everything else just succeeds.
printf '#!/usr/bin/env bash\n[[ $1 == cat ]] && exit "${HAS_BLUETOOTH:-0}"\nexit 0\n' >"$sandbox/bin/systemctl"
chmod +x "$sandbox/bin/sudo" "$sandbox/bin/systemctl"

run() {
  PATH="$sandbox/bin:$PATH" DESKTOP_SYSTEMD_SYSTEM_PATH="$sandbox/$1" \
    bash "$ROOT/install/config/hardware/bluetooth.sh"
}
dropin="$sandbox/etc/bluetooth.service.d/10-restart.conf"

first=$(run etc)
check "the drop-in is written, and says so" test -n "$first" -a -f "$dropin"
check "it restarts the service on failure" grep -qx 'Restart=on-failure' "$dropin"
check "under [Service], where systemd reads it" test "$(head -1 "$dropin")" = "[Service]"
check "systemd is told to read it" grep -q 'systemctl daemon-reload' "$sandbox/calls"

: >"$sandbox/calls"
second=$(run etc)
check "a second run changes nothing and asks for no password" test -z "$second" -a ! -s "$sandbox/calls"

mkdir -p "$sandbox/none"
HAS_BLUETOOTH=1 run none >/dev/null
check "a machine without bluez gets no drop-in" test ! -e "$sandbox/none/bluetooth.service.d"

check "the migration runs the installer's script" \
  grep -q 'install/config/hardware/bluetooth.sh' "$ROOT/migrations/1791790791.sh"

finish
