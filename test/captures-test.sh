#!/usr/bin/env bash
# desktop-captures: the recordings and meeting captures the panels list.
#
# What matters is what a person reads: the name given at start without its timestamp,
# the first line that was actually said -- not a "## You" heading or a "(silent ...)"
# note -- and a word count that does not count those either. Videos is often a symlink
# into a data disk, as it is on this machine, and must still be listed.
source "$(dirname "$0")/lib.sh"

require jq find || finish

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
mkdir -p "$sandbox/path" "$sandbox/data/Videos/Meetings"
ln -s "$sandbox/data/Videos" "$sandbox/Videos"
for tool in bash env jq find sort head grep cut wc sed basename; do ln -s "$(command -v "$tool")" "$sandbox/path/$tool"; done
cat >"$sandbox/path/ffprobe" <<'STUB'
#!/usr/bin/env bash
echo 91.4
STUB
chmod +x "$sandbox/path/ffprobe"

meetings=$sandbox/data/Videos/Meetings
: >"$meetings/standup-2026-09-17_09-00-00.flac"
printf '## Them\n\n(silent -- nothing was recorded on this side)\n\n## You\n\nGood morning, shall we start?\n' >"$meetings/standup-2026-09-17_09-00-00.txt"
: >"$meetings/meeting-2026-09-18_13-19-22.flac"
touch -d '2026-09-17 09:00' "$meetings/standup-2026-09-17_09-00-00.flac"
touch -d '2026-09-18 13:19' "$meetings/meeting-2026-09-18_13-19-22.flac"
: >"$sandbox/data/Videos/screenrecording-2026-09-18_10-00-00.mp4"

captures() { env -i PATH="$sandbox/path" HOME="$sandbox" bash "$ROOT/bin/desktop-captures" "$@"; }
out=$(captures meetings)

check "through a symlinked Videos, newest first" test "$(jq -r '[.[].name] | join(" ")' <<<"$out")" = "meeting standup"
check "the preview is the first thing said, not a heading or a note" \
  test "$(jq -r '.[1].preview' <<<"$out")" = "Good morning, shall we start?"
check "and headings and notes are not counted as words" test "$(jq -r '.[1].words' <<<"$out")" = 5
check "a capture with no transcript yet says so" test "$(jq -r '.[0].transcript' <<<"$out")" = null
check "the length is whole seconds" test "$(jq -r '.[0].seconds' <<<"$out")" = 91
check "screen recordings are listed from Videos itself" test "$(captures screen | jq -r '.[0].name')" = screenrecording
check "a missing folder is an empty list, not an error" \
  test "$(env -i PATH="$sandbox/path" HOME="$sandbox/nowhere" bash "$ROOT/bin/desktop-captures" meetings)" = "[]"

finish
