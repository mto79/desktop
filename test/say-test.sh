#!/usr/bin/env bash
# desktop-say speaks, and the checks here are mostly about when it must not: switched off,
# during do-not-disturb, while a microphone is being listened to, and after being told to
# be quiet. Everything that makes a sound is a stub.
source "$(dirname "$0")/lib.sh"

SAY="$ROOT/bin/desktop-say"
sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
stubs="$sandbox/stubs"
mkdir -p "$stubs"

# The fallback voice writes what it was asked to say into the "sound" file.
cat >"$stubs/espeak-ng" <<'STUB'
#!/usr/bin/env bash
while (($#)); do case "$1" in -w) out=$2; shift ;; --) shift; printf '%s' "$1" >"$out" ;; esac; shift; done
STUB
# The player says what it played, and takes as long as it is told to.
cat >"$stubs/pw-play" <<STUB
#!/usr/bin/env bash
cat "\$1" >>"$sandbox/played"; echo >>"$sandbox/played"
sleep "\${PLAY_SECONDS:-0}"
STUB
printf '#!/usr/bin/env bash\n[[ -e "%s/mic" ]] && echo "12 34 56 voxtype"\nexit 0\n' "$sandbox" >"$stubs/pactl"
printf '#!/usr/bin/env bash\n[[ -e "%s/dnd" ]] && echo on || echo off\n' "$sandbox" >"$stubs/desktop-shell"
chmod +x "$stubs"/*

run() {
  PATH="$stubs:$PATH" XDG_STATE_HOME="$sandbox/state" XDG_RUNTIME_DIR="$sandbox/run" \
    XDG_CONFIG_HOME="$sandbox/config" DESKTOP_SAY_DATA="$sandbox/data" bash "$SAY" "$@"
}
played() { cat "$sandbox/played" 2>/dev/null; }
fresh() { rm -f "$sandbox/played"; }

run "desktop is waiting for you"
check "a line is spoken" grep -qx "desktop is waiting for you" <<<"$(played)"

# --- when not to
fresh; run --mute; run "muted line"
check "switched off, it says nothing" test -z "$(played)"
check "and says so when asked" test "$(run --status)" = off
run --unmute
check "switched on again" test "$(run --status)" = on

fresh; touch "$sandbox/mic"; run "during a call"
check "nothing while a microphone is being listened to" test -z "$(played)"
rm "$sandbox/mic"

fresh; touch "$sandbox/dnd"; run "during do not disturb"
check "nothing while do-not-disturb is on" test -z "$(played)"
rm "$sandbox/dnd"

# --- one at a time, and not too late
fresh
PLAY_SECONDS=1 run "first" &
sleep 0.3
run "second"
wait
check "two lines are said in the order they came, not over each other" \
  test "$(played | tr '\n' ' ')" = "first second "

fresh
PLAY_SECONDS=2 run "long one" &
sleep 0.3
DESKTOP_SAY_MAX_WAIT=1 run "stale by the time it could be said"
wait
check "a line that waited too long is dropped" lacks stale <<<"$(played)"

fresh
PLAY_SECONDS=2 run "talking" &
sleep 0.3
run "queued behind it" &
sleep 0.3
run --hush
wait
check "hush drops what was waiting to be said" lacks queued <<<"$(played)"
check "and stops the one being said" test ! -e "$sandbox/run/desktop/say/playing"

# --- what the shell shows while it speaks
# A small file that exists for as long as there is something to show.
now="$sandbox/run/desktop/say/now"
fresh
PLAY_SECONDS=1 run "roll out to ocp204" &
sleep 0.5
check "while it speaks, what is being said is published" test "$(jq -r .state "$now" 2>/dev/null)" = speaking
check "as it was written, not as it is pronounced" test "$(jq -r .text "$now" 2>/dev/null)" = "roll out to ocp204"
wait
check "and withdrawn when it has been said" test ! -e "$now"
PLAY_SECONDS=2 run "to be cut off" &
sleep 0.5
run --hush
check "hush withdraws it at once" test ! -e "$now"
wait
check "and leaves nothing behind" test -z "$(ls "$sandbox/run/desktop/say" | grep -v -e '^lock$' -e '^hushed$')"
fresh; run --mute; run "muted"; run --unmute
check "nothing is shown for a line that is not said" test ! -e "$now"

VOICE_QML="$ROOT/shell/Voice/Voice.qml"
SPEECH_QML="$ROOT/shell/Commons/Speech.qml"
check "the shell follows that file" grep -q '"/desktop/say/now"' "$SPEECH_QML"
check "in one place, for the corner card and the dashboard both" \
  test "$(grep -l 'Speech\.' "$VOICE_QML" "$ROOT/shell/Dashboard/Dashboard.qml" | wc -l)" = 2
check "which draw the same thing at two sizes" \
  test "$(grep -c '^ *Orb {' "$VOICE_QML" "$ROOT/shell/Dashboard/Dashboard.qml" | cut -d: -f2 | paste -sd+ | bc)" = 2
check "the corner card steps aside while the dashboard is in front" grep -q 'Speech.active && !onDashboard' "$VOICE_QML"
check "the card is part of the shell" grep -q '^  Voice {}' "$ROOT/shell/shell.qml"
# It is there to be glanced at: it must take no clicks and no keys from what is under it.
check "the card takes no input" lacks -E 'interactive: true|focusable: true|MouseArea' "$VOICE_QML"
check "and cannot outstay a speaker that died without tidying up" grep -q 'property Timer giveUp' "$SPEECH_QML"

# --- how things are said
mkdir -p "$sandbox/config/desktop"
cp "$ROOT/config/desktop/say.dict" "$sandbox/config/desktop/say.dict"
check "a cluster's name is spelled out" \
  test "$(run --pronounce 'roll out to ocp204')" = "roll out to O C P 2 oh 4"
check "a hyphenated project is words" \
  test "$(run --pronounce 'minio-manager-infra-resources is done')" = "min I O manager infra resources is done"
check "a task in a repository reads as a pause" \
  test "$(run --pronounce 'desktop · fix-runner is waiting')" = "desktop, fix runner is waiting"
check "markup and quotes are not read out" \
  test "$(run --pronounce '<b>“Certificate”</b> renewal')" = "bCertificate, b renewal" -o \
  "$(run --pronounce '“Certificate” *renewal*')" = "Certificate renewal"
check "a line is kept to a line" test "$(run --pronounce "$(printf 'word %.0s' $(seq 100))" | wc -c)" -le 222
printf 'broken[\tx\n' >"$sandbox/config/desktop/say.dict"
check "a bad rule in the dictionary does not silence it" \
  test "$(run --pronounce 'still said')" = "still said"

# --- the voice
check "the engine is pinned to one version" grep -q '^PIPER_VERSION="[0-9.]*"$' "$SAY"
# Every voice on offer is fetched from the network, so every one carries its checksums.
voices=$(sed -n '/^VOICES=(/,/^)/p' "$SAY" | grep '^  "')
check "there are voices to choose from" test "$(wc -l <<<"$voices")" -ge 3
check "each with a checksum for the model and for its settings" \
  test "$(grep -cE '\|[0-9a-f]{64}\|[0-9a-f]{64}"$' <<<"$voices")" = "$(wc -l <<<"$voices")"
check "the list says which is in use" test "$(run --voices --json | jq -r '[.voices[] | select(.current)] | length')" = 1
mkdir -p "$sandbox/state/desktop/say"
echo "a-voice-that-was-dropped" >"$sandbox/state/desktop/say/voice"
check "a chosen voice that is no longer on the list falls back to the default" \
  test "$(run --status --json | jq -r .voice)" = "$(sed -n 's/^DEFAULT_VOICE="\(.*\)"$/\1/p' "$SAY")"
rm -f "$sandbox/state/desktop/say/voice"
check "a voice that is not on the list cannot be chosen" lacks . <<<"$(run --voice not-a-voice 2>/dev/null)"
check "the panel offers them" grep -q '"desktop-say", "--voice", name' "$ROOT/shell/Bar/panels/AiPanel.qml"
check "what is spoken is not sent anywhere to be turned into speech" lacks -i 'edge-tts\|api\.' "$SAY"
check "without the voice it falls back and says which" \
  test "$(run --status --json | jq -r .engine)" = espeak-ng

# --- wired in
check "starting a dictation cuts it off" grep -q 'desktop-say --hush' "$ROOT/bin/desktop-dictate"
check "the install sets the voice up" grep -q 'desktop-say" --setup' "$ROOT/install/packaging/say.sh"
check "and is run" grep -qx 'source "$DESKTOP_INSTALL/packaging/say.sh"' "$ROOT/install/packaging/all.sh"
check "the fallback voice is installed with the desktop" grep -qxF espeak-ng "$ROOT/install/desktop-base.packages"
check "the shell can be asked about do-not-disturb" grep -q 'function isQuiet(): string' "$ROOT/shell/shell.qml"
check "the switch is in the AI panel" grep -q '"desktop-say", "--toggle"' "$ROOT/shell/Bar/panels/AiPanel.qml"

finish
