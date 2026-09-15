#!/usr/bin/env bash
# Capturing both sides of a call, and the two ways the transcript lies if you let it.
#
# A sink's monitor carries only the far end; your own voice arrives through the
# microphone. Both are recorded, kept as separate channels, and transcribed separately --
# mixing them made the result worse, because the monitor arrives near full scale and a
# microphone sits sixty decibels below it.
#
# The two failures worth guarding: voxtype prints its own log to stdout alongside the
# transcript, so the text has to be picked out of it rather than captured wholesale; and
# a silent side does not transcribe to nothing, it transcribes to "Thank you." -- which
# under a speaker heading reads exactly like something somebody said.
source "$(dirname "$0")/lib.sh"

require python3 || finish

CAPTURE="$ROOT/bin/desktop-meeting-capture"

sandbox=$(mktemp -d)
# The recording stub loops until interrupted; a failed test must not leave it running.
trap 'pkill -f "$sandbox/bin/ffmpeg" 2>/dev/null; rm -rf "$sandbox"' EXIT

# A tone and a near-silent hiss, at levels taken from a real capture: the monitor side
# peaked at 0 dBFS and the idle microphone at about -44.
python3 - "$sandbox" <<'PY'
import math, struct, sys, wave

def write(path, amplitude):
    with wave.open(path, "w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(16000)
        frames = [int(amplitude * 32767 * math.sin(i * 0.1)) for i in range(16000)]
        w.writeframes(struct.pack(f"<{len(frames)}h", *frames))

write(f"{sys.argv[1]}/loud.wav", 1.0)      #   0 dBFS
write(f"{sys.argv[1]}/quiet.wav", 0.006)   # ~-44 dBFS, an idle mic
PY

# The level check, lifted out of the script so it can be exercised directly.
eval "$(sed -n '/^channel_has_speech() {/,/^}$/p' "$CAPTURE")"

check "a channel with speech in it is transcribed" channel_has_speech "$sandbox/loud.wav"
if channel_has_speech "$sandbox/quiet.wav"; then
  fail "an idle microphone is not transcribed" "a -44 dBFS hiss was taken for speech"
else
  pass "an idle microphone is not transcribed"
fi

# The transcript extraction, against voxtype's real output shape.
noise=$(cat <<'OUT'
Loading audio file: "/tmp/x.wav"
Audio format: 16000 Hz, 1 channel(s), Int
Processing 44246 samples (2.77s)...
2026-09-15T09:30:51.599425Z  INFO Using local whisper transcription mode
2026-09-15T09:30:54.546157Z  INFO Transcription completed in 0.87s: "The quarterly report is due on Friday."

The quarterly report is due on Friday.
OUT
)
extracted=$(sed -e 's/\x1b\[[0-9;]*m//g' \
  -e '/^Loading audio file/d' -e '/^Audio format/d' -e '/^Processing /d' \
  -e '/^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T/d' -e '/^[[:space:]]*$/d' <<<"$noise")
check "the transcript is picked out of voxtype's own chatter" \
  test "$extracted" = "The quarterly report is due on Friday."

# The whole flow, with every external command stubbed: no audio hardware, no model.
stubs="$sandbox/bin"; mkdir -p "$stubs" "$sandbox/out"
cat >"$stubs/pactl" <<'STUB'
#!/usr/bin/env bash
case "$*" in
"get-default-sink") echo "testsink" ;;
"get-default-source") echo "testsource" ;;
*) ;;
esac
STUB
# ffmpeg either "records" (sleeps until interrupted, leaving a file) or converts.
cat >"$stubs/ffmpeg" <<'STUB'
#!/usr/bin/env bash
out="${@: -1}"
if [[ $* == *-f\ pulse* ]]; then
  printf 'flac' >"$out"
  trap 'exit 0' INT
  while :; do sleep 0.1; done
else
  cp "$FIXTURE_WAV" "$out"
fi
STUB
cat >"$stubs/voxtype" <<'STUB'
#!/usr/bin/env bash
echo 'Loading audio file: "x"'
echo "2026-09-15T09:30:51.599425Z  INFO noise"
echo
echo "the words that were said"
STUB
printf '#!/usr/bin/env bash\nexit 0\n' >"$stubs/notify-send"
chmod +x "$stubs"/*

run() {
  XDG_RUNTIME_DIR="$sandbox/run" DESKTOP_MEETING_DIR="$sandbox/out" \
    FIXTURE_WAV="$sandbox/loud.wav" PATH="$stubs:$PATH" bash "$CAPTURE" "$@"
}

check "nothing is recording to begin with" test "$(run status)" = "idle"
run start standup >/dev/null
check "starting reports what it is recording" grep -q "recording standup" <<<"$(run status)"
check "a second start is refused rather than layered on top" \
  lacks . <<<"$(run start again 2>/dev/null || true)"
run stop >/dev/null

transcript=$(cat "$sandbox/out"/*.txt)
check "both sides are labelled" \
  test "$(grep -c '^## ' <<<"$transcript")" = 2
check "the far end is transcribed" grep -q "the words that were said" <<<"$transcript"
check "voxtype's log does not end up in the transcript" \
  lacks "INFO" <<<"$transcript"
check "the audio is kept alongside it" test -n "$(find "$sandbox/out" -name '*.flac')"
check "no intermediate wavs are left behind" \
  test -z "$(find "$sandbox/out" -name '*.ch[01].wav')"
check "stopping when idle is refused" lacks . <<<"$(run stop 2>/dev/null || true)"

finish
