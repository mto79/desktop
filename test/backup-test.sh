#!/usr/bin/env bash
# A real backup, into a repository made and thrown away inside the test.
#
# restic is fast enough on a directory repository that there is no reason to fake it,
# and the parts worth guarding are the ones only a real run exercises: that a snapshot
# id is parsed out of restic's output and remembered, that the state file is what makes
# the bar work with the NAS switched off, and above all that a restore lands beside the
# original rather than on top of it.
source "$(dirname "$0")/lib.sh"

require restic || finish
require jq || finish

BACKUP="$ROOT/bin/desktop-backup"

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
mkdir -p "$sandbox/bin" "$sandbox/data" "$sandbox/.config/desktop"

# The real one would put a notification on the screen of whoever runs the suite.
printf '#!/usr/bin/env bash\nexit 0\n' >"$sandbox/bin/notify-send"
chmod +x "$sandbox/bin/notify-send"

printf 'the original\n' >"$sandbox/data/keep.txt"

cat >"$sandbox/.config/desktop/backup.conf" <<CONFIG
BACKUP_REPOSITORY="$sandbox/repo"
BACKUP_HOST=""
BACKUP_PASSWORD_FILE="$sandbox/.config/desktop/restic-password"
BACKUP_PATHS=("$sandbox/data")
BACKUP_EXCLUDES=()
BACKUP_KEEP_DAILY=7
BACKUP_KEEP_WEEKLY=5
BACKUP_KEEP_MONTHLY=12
CONFIG

# XDG_STATE_HOME is set in a desktop session, and the script rightly prefers it over
# $HOME -- so a sandboxed HOME alone is not sandboxed at all. The first run of this test
# wrote a "last backup" record into the real state directory, claiming a backup that had
# only ever existed inside a temporary directory.
backup() {
  HOME="$sandbox" XDG_STATE_HOME="$sandbox/.local/state" PATH="$sandbox/bin:$PATH" \
    DESKTOP_BACKUP_CONF="$sandbox/.config/desktop/backup.conf" \
    bash "$BACKUP" "$@"
}

# No password file yet, so there is nothing this could even try.
check "a repository without a password reads as unconfigured" \
  test "$(backup status --json | jq -r .state)" = "unconfigured"

printf 'test-password-not-a-real-one\n' >"$sandbox/.config/desktop/restic-password"
chmod 600 "$sandbox/.config/desktop/restic-password"

backup init >/dev/null 2>&1
check "init creates the repository" test -f "$sandbox/repo/config"

# Never backed up, but now able to: that is a different state from not being set up, and
# the bar colours the two the same way for the same reason.
check "a repository with nothing in it reads as never" \
  test "$(backup status --json | jq -r .state)" = "never"

out=$(backup 2>&1)
if [[ $? -eq 0 ]]; then
  pass "a backup runs"
else
  fail "a backup runs" "$out"
fi

check "the snapshot id is remembered locally" \
  test -s "$sandbox/.local/state/desktop/backup-last"
# Without this the bar would have to reach the NAS to say how old the last backup is,
# which is exactly what it cannot do when the answer matters.
check "the state file names a snapshot, not just a time" \
  test -n "$(awk '{print $2}' "$sandbox/.local/state/desktop/backup-last")"

report=$(backup status --json)
check "a fresh backup reads as ok" test "$(jq -r .state <<<"$report")" = "ok"
check "the snapshot reaches the panel" test "$(jq -r '.snapshots | length' <<<"$report")" = "1"
check "the bar module stays icon-only" test "$(backup status --bar | jq -r .text)" = ""
check "the bar module reports the state" test "$(backup status --bar | jq -r .class)" = "ok"

id=$(jq -r '.snapshots[0].id' <<<"$report")
check "snapshots list by id" grep -q "$id" <<<"$(backup snapshots)"

# The whole point. A restore is a copy placed beside the original, never over it.
printf 'edited since the backup\n' >"$sandbox/data/keep.txt"
backup restore "$id" >/dev/null 2>&1
check "the original is left exactly as it was" \
  test "$(cat "$sandbox/data/keep.txt")" = "edited since the backup"

restored=$(find "$sandbox/Restored" -name keep.txt -print -quit 2>/dev/null)
if [[ -n $restored && "$(cat "$restored")" == "the original" ]]; then
  pass "the restored copy lands under ~/Restored with the old contents"
else
  fail "the restored copy lands under ~/Restored with the old contents" "found '${restored:-nothing}'"
fi
finish
