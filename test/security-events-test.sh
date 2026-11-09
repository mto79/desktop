#!/usr/bin/env bash
# Rules over the journal. What matters: a line a rule knows becomes an event of the right
# severity, a run of them inside the window becomes one alert and not a dozen, and a rule
# that saw nothing still says it looked -- "nothing happened" and "nobody was looking" must
# not read the same.
source "$(dirname "$0")/lib.sh"

require python3 || finish
require jq || finish

EVENTS="$ROOT/bin/desktop-security-events"
sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
now=$(date +%s)

# line <seconds ago> <identifier> <message> [transport]
line() {
  jq -cn --arg t "$(((now - $1) * 1000000))" --arg id "$2" --arg m "$3" --arg tr "${4:-syslog}" \
    '{__REALTIME_TIMESTAMP: $t, SYSLOG_IDENTIFIER: $id, MESSAGE: $m, _TRANSPORT: $tr}'
}

{
  line 100 sudo 'pam_unix(sudo:auth): authentication failure; logname=u uid=1000'
  line 120 sudo 'pam_unix(sudo:auth): authentication failure; logname=u uid=1000'
  line 140 sudo 'pam_unix(sudo:auth): authentication failure; logname=u uid=1000'
  line 160 sudo 'pam_unix(sudo:auth): authentication failure; logname=u uid=1000'
  line 180 sudo 'pam_unix(sudo:auth): authentication failure; logname=u uid=1000'
  line 200 sudo 'u : TTY=pts/1 ; PWD=/home/u ; USER=root ; COMMAND=/usr/bin/true'
  line 300 sshd-session 'Accepted publickey for u from 192.0.2.7 port 2222 ssh2'
  line 400 kernel 'usb 5-2: New USB device found, idVendor=1050, idProduct=0407' kernel
  line 500 audit 'AVC avc:  denied  { read } for pid=1 comm="x" scontext=a tcontext=b' audit
  line 600 kernel 'filter_IN_public_REJECT: IN=wlan0 SRC=192.0.2.9' kernel
  line 700 systemd-logind 'New session 4 of user u.'
  line 800 sudo 'something a rule does not know'
  echo 'not json'
} >"$sandbox/journal"

answer=$("$EVENTS" --json --from "$sandbox/journal")
field() { jq -r "$1" <<<"$answer"; }
rule() { field ".rules[] | select(.id == \"$1\") | .count"; }

check "a line nothing recognises is no event, and a broken one no failure" test "$(field .total)" = 11
check "failed sudo is counted" test "$(rule sudo-denied)" = 5
check "and is medium" test "$(field '.rules[] | select(.id == "sudo-denied") | .severity')" = medium
check "a command through sudo is only information" test "$(rule sudo-run)" = 1
check "an SSH login is high, on a machine with sshd off" test "$(field .severity.high)" = 1
check "an AVC is read from the audit transport" test "$(rule avc-denied)" = 1
check "a USB device from the kernel's" test "$(rule usb-new)" = 1
check "a firewall refusal too" test "$(rule firewall-drop)" = 1

check "five failures in ten minutes are one alert" test "$(field '.alerts | length')" = 1
check "of high severity" test "$(field '.alerts[0].severity')" = high
check "counting all five" test "$(field '.alerts[0].count')" = 5

check "a rule that saw nothing still says it looked" test "$(rule oom)" = 0
check "newest first" test "$(field '.events[0].rule')" = sudo-denied
check "with a timeline for the period" test "$(field '.timeline | length')" = 24
check "whose hours add up" test "$(field '[.timeline[].value] | add')" = 11

# Far enough apart, the same five are no attack.
{
  for ago in 100 900 1700 2500 3300; do line "$ago" sudo 'authentication failure; logname=u'; done
} >"$sandbox/slow"
check "five failures over an hour are not an alert" \
  test "$("$EVENTS" --json --from "$sandbox/slow" | jq '.alerts | length')" = 0

finish
