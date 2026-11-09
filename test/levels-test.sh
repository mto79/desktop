#!/usr/bin/env bash
# The default output's and microphone's volume and mute, as shell/Commons/levels.js reads
# them from wpctl and decides which of pactl's events are worth asking again for.
#
# This exists because Quickshell's own copy went stale: a Bluetooth headset that dropped and
# reconnected read as muted on the bar while PipeWire had it at 80%. The shell now asks
# wpctl, so what wpctl prints has to be read right -- a mute, a missing microphone, and
# never one device's answer in the other's place.
source "$(dirname "$0")/lib.sh"

require node || finish

levels() {
  node -e "
    const l = require('$ROOT/shell/Commons/levels.js');
    $1"
}

check "a volume is read as the fraction wpctl prints" \
  test "$(levels "console.log(l.parse('sink Volume: 0.80\nsource Volume: 0.55\n').sink.volume)")" = 0.8
check "and is not muted unless it says so" \
  test "$(levels "console.log(l.parse('sink Volume: 0.80\n').sink.muted)")" = false
check "a mute is read as one" \
  test "$(levels "console.log(l.parse('sink Volume: 0.80 [MUTED]\n').sink.muted)")" = true
check "each device keeps its own answer" \
  test "$(levels "const f = l.parse('sink Volume: 0.80\nsource Volume: 0.47 [MUTED]\n');
    console.log(f.sink.muted, f.source.volume, f.source.muted)")" = "false 0.47 true"
check "a missing microphone leaves it out rather than borrowing the output's" \
  test "$(levels "const f = l.parse('sink Volume: 0.80\n\nsource \n');
    console.log(!!f.sink, !!f.source)")" = "true false"
check "above 100% is kept as it is" \
  test "$(levels "console.log(l.parse('sink Volume: 1.25\n').sink.volume)")" = 1.25

check "a device changing is worth asking again" \
  test "$(levels "console.log(l.matters(\"Event 'change' on sink #307\"))")" = true
check "so is a new default" \
  test "$(levels "console.log(l.matters(\"Event 'change' on server #4294967295\"))")" = true
check "and a headset coming back" \
  test "$(levels "console.log(l.matters(\"Event 'new' on card #302\"))")" = true
check "a stream is not: they change all through playback" \
  test "$(levels "console.log(l.matters(\"Event 'change' on sink-input #62\"),
    l.matters(\"Event 'change' on source-output #51\"))")" = "false false"

finish
