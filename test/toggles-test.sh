#!/usr/bin/env bash
# The recording toggle's state, without recording anything.
#
# The widget binds to these field names and does arithmetic on `elapsed`, so the shape
# is the contract: a string where a number belongs renders as "NaN:aN" on the bar, and a
# renamed field renders as nothing at all. Neither says a word in the log.
source "$(dirname "$0")/lib.sh"

require jq || finish

STATUS="$ROOT/bin/desktop-status-screenrecord"

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
mkdir -p "$sandbox/bin"

# Nothing is recording, whatever this machine happens to be doing while the suite runs.
cat >"$sandbox/bin/pgrep" <<'STUB'
#!/usr/bin/env bash
exit 1
STUB
chmod +x "$sandbox/bin/pgrep"

idle=$(PATH="$sandbox/bin:$PATH" bash "$STATUS")
if jq -e . >/dev/null 2>&1 <<<"$idle"; then
  pass "the recording status prints parseable JSON"
else
  fail "the recording status prints parseable JSON" "$idle"
fi
check "an idle desktop reports no recording" \
  test "$(jq -r '.active | tostring' <<<"$idle")" = "false"
check "an idle desktop still offers the tooltip that starts one" \
  test -n "$(jq -r '.tooltip' <<<"$idle")"

# And now one that is. ps reports the elapsed seconds; the widget counts up from there
# rather than asking again every second.
cat >"$sandbox/bin/pgrep" <<'STUB'
#!/usr/bin/env bash
[[ "$*" == *wf-recorder* ]] && echo 4242
exit 0
STUB
cat >"$sandbox/bin/ps" <<'STUB'
#!/usr/bin/env bash
echo "    93"
STUB
chmod +x "$sandbox/bin/pgrep" "$sandbox/bin/ps"

busy=$(PATH="$sandbox/bin:$PATH" bash "$STATUS")
check "a running recorder is reported" test "$(jq -r '.active | tostring' <<<"$busy")" = "true"
check "the elapsed time comes through as a number" \
  test "$(jq -r '.elapsed | type' <<<"$busy")" = "number"
check "the elapsed time is the one ps gave" test "$(jq -r .elapsed <<<"$busy")" = "93"
check "the recorder names itself" test "$(jq -r .tool <<<"$busy")" = "wf-recorder"

missing=$(jq -r '[ (has("active")|not|select(.)|"active"),
                   (has("elapsed")|not|select(.)|"elapsed"),
                   (has("tool")|not|select(.)|"tool"),
                   (has("tooltip")|not|select(.)|"tooltip") ] | join(" ")' <<<"$busy")
if [[ -z $missing ]]; then
  pass "every field the toggle binds to is present"
else
  fail "every field the toggle binds to is present" "$missing"
fi
finish
