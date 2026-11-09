#!/usr/bin/env bash
# What came and went between scans. What matters is what must not be reported: the first
# scan of a network as all new, a quiet scan after a sweep as half the house gone, another
# network's devices as gone from this one, and a phone's rotating Bluetooth address as a
# stream of new devices.
source "$(dirname "$0")/lib.sh"

require python3 || finish
require jq || finish

CHANGES="$ROOT/bin/desktop-scan-changes"
sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
export XDG_STATE_HOME="$sandbox/state"
net="$sandbox/state/desktop/netscan"
bt="$sandbox/state/desktop/btscan"
mkdir -p "$net" "$bt"

# scan <place> <swept> <mac>... : a network scan with those devices, the router first.
scan() {
  local place=$1 swept=$2
  shift 2
  jq -cn --arg place "$place" --argjson swept "$swept" --args '{
    checked: now | floor, place: $place, swept: $swept, link: {cidr: "192.0.2.0/24"},
    devices: ([{ip: "192.0.2.10", mac: "00:00:5e:00:53:10", me: true}] +
      ($ARGS.positional | to_entries | map({ip: "192.0.2.\(.key + 20)", mac: .value, name: "device \(.key)", vendor: ""})))
  }' "$@"
}
# record <answer>: what a scan would do, record and then keep the answer as the last one.
record() {
  local answer=$1 out
  out=$("$CHANGES" record net <<<"$answer")
  printf '%s\n' "$answer" >"$net/last.json"
  printf '%s' "$out"
}
count() { jq "$1 | length" <<<"$2"; }

a="00:00:5e:00:53:01" b="00:00:5e:00:53:02" c="00:00:5e:00:53:03"

first=$(record "$(scan Home true "$a" "$b")")
check "the first scan of a network says it is the first" test "$(jq .first <<<"$first")" = true
check "and calls nothing new" test "$(count .new "$first")" = 0
check "and logs nothing" test ! -s "$net/changes.jsonl"

second=$(record "$(scan Home true "$a" "$c")")
check "a device never seen here is new" test "$(jq -r '.new[0].key' <<<"$second")" = "$c"
check "one from the last scan that is missing is gone" test "$(jq -r '.gone[0].key' <<<"$second")" = "$b"
check "this machine is no device of its own" test "$(count .new "$second")" = 1

third=$(record "$(scan Home true "$a" "$b" "$c")")
check "a device seen before, missing last time, is back" test "$(jq -r '.back[0].key' <<<"$third")" = "$b"
check "and not new" test "$(count .new "$third")" = 0

quiet=$(record "$(scan Home false "$a")")
check "a quiet scan after a sweep reports nothing gone" test "$(count .gone "$quiet")" = 0

sweep=$(record "$(scan Home true "$a" "$b" "$c")")
check "nor does the sweep after it call what the quiet one missed back" test "$(count .back "$sweep")" = 0
elsewhere=$(record "$(scan Office true "$c")")
check "another network is a first scan of its own" test "$(jq .first <<<"$elsewhere")" = true
check "and nothing at home is gone because of it" test "$(count .gone "$elsewhere")" = 0

log=$("$CHANGES" show net)
check "the log is newest first" test "$(jq -r '.events[0].event' <<<"$log")" = back
check "with what changed, where and when" test "$(jq -r '.events[0] | [.scope, .label, (.at > 0)] | join(" ")' <<<"$log")" = "Home device 1 true"
check "every change is in it, and nothing else" test "$(count .events "$log")" = 3
check "and is readable by you alone" test "$(stat -c %a "$net/changes.jsonl")" = 600

# A device heard only over mDNS has no MAC yet; the next scan has it. One device, not two.
mdns() { jq -cn --arg mac "$1" '{checked: 1, place: "Lounge", swept: false, link: {cidr: "192.0.2.0/24"},
  devices: [{ip: "192.0.2.50", mac: $mac, name: "speaker", vendor: ""}]}'; }
record "$(mdns "")" >/dev/null
heard=$(record "$(mdns 00:00:5e:00:53:50)")
check "a device first heard without its MAC is not new once the MAC is known" test "$(count .new "$heard")" = 0
check "nor gone under its old name" test "$(count .gone "$heard")" = 0
lost=$(record "$(mdns "")")
check "nor the other way round" test "$(( $(count .new "$lost") + $(count .gone "$lost") ))" = 0

# --- Bluetooth
blue() { # near-address... ; a random one rides along every time with a new address
  jq -cn --arg r "$(printf '00:00:5E:00:53:%02X' $((RANDOM % 200)))" --args '{
    checked: now | floor, powered: true,
    devices: (($ARGS.positional | map({address: ., name: "thing", random: false, near: true}))
      + [{address: $r, name: "", random: true, near: true}])
  }' "$@"
}
brecord() {
  local out
  out=$("$CHANGES" record bt <<<"$1")
  printf '%s\n' "$1" >"$bt/last.json"
  printf '%s' "$out"
}
brecord "$(blue 00:00:5E:00:53:A1)" >/dev/null
again=$(brecord "$(blue 00:00:5E:00:53:A1 00:00:5E:00:53:A2)")
check "a Bluetooth device heard for the first time is new" test "$(jq -r '.new[0].key' <<<"$again")" = 00:00:5E:00:53:A2
check "a rotating random address is never new" test "$(count .new "$again")" = 1
check "nor gone" test "$(count .gone "$again")" = 0
off=$("$CHANGES" record bt <<<'{"checked": 1, "powered": false, "devices": []}')
check "Bluetooth switched off is not everything gone" test "$(count .gone "$off")" = 0

for scanner in desktop-netscan desktop-btscan; do
  check "$scanner records what changed before it replaces its last answer" \
    test "$(grep -n 'answer\["changes"\] = changes(answer)' "$ROOT/bin/$scanner" | cut -d: -f1)" -lt "$(grep -n 'os.replace(LAST' "$ROOT/bin/$scanner" | cut -d: -f1)"
done
check "the dashboard shows it under each radar" test "$(grep -c '^  ChangesCard {' "$ROOT/shell/Dashboard/InfraPage.qml")" = 2

finish
