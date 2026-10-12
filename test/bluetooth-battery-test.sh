#!/usr/bin/env bash
# The headset's low-battery warning, decided in shell/Commons/lowbattery.js.
#
# What matters is how often it speaks: a WH-1000XM4 reports in steps of ten and sits on
# 10% for an hour, during which bluez republishes the same figure again and again. Once
# on the way down, and again only after a charge or a reconnect.
source "$(dirname "$0")/lib.sh"

require node || finish

low() {
  node -e "
    const b = require('$ROOT/shell/Commons/lowbattery.js');
    $1"
}

# Feed a run of levels through as the shell does -- carrying `warned` from one reading
# to the next -- and print the levels a notification went out at.
run() {
  low "
    let warned = false; const said = [];
    for (const level of [$1]) {
      const r = b.step(level, warned, 15);
      warned = r.warned;
      if (r.notify) said.push(level);
    }
    console.log(said.join(' '));"
}

check "a percentage is taken as it is" test "$(low "console.log(b.percent(true, 70))")" = 70
check "a fraction is turned into one" test "$(low "console.log(b.percent(true, 0.7))")" = 70
check "a full headset is 100%, whichever it was given" \
  test "$(low "console.log(b.percent(true, 1), b.percent(true, 100))")" = "100 100"
check "a device with no battery to report has no level" test "$(low "console.log(b.percent(false, 0))")" = -1

check "nothing is said above the threshold" test "$(run "100, 50, 20")" = ""
check "a draining headset is warned about once" test "$(run "30, 20, 10, 10, 10, 0")" = "10"
check "the threshold itself counts as low" test "$(run "20, 15")" = "15"
check "a charge re-arms the warning" test "$(run "10, 10, 60, 20, 10")" = "10 10"
check "a level that stops being reported re-arms it too" test "$(run "10, -1, 10")" = "10 10"

# The warning is sent from a singleton because the bar exists once per monitor; one
# missing from qmldir fails the whole shell to load.
check "the singleton is exported by qmldir" \
  grep -q '^singleton BluetoothBattery ' "$ROOT/shell/Commons/qmldir"

finish
