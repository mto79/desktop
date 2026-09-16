#!/usr/bin/env bash
# What the AI module says, worked out without a network and without credentials.
#
# The module reports how full the fullest Claude limit is. Three things it must not do:
# headline the extra-usage cap, which is money rather than tokens and would read as a
# token percentage on a bar that has no room to explain itself; go silent when the
# endpoint cannot be reached, which is exactly when a stale number is worth most; and
# let a running agent hide a limit that has gone critical.
source "$(dirname "$0")/lib.sh"

require python3 || finish
require jq || finish

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
mkdir -p "$sandbox/run/desktop" "$sandbox/config" "$sandbox/bin"

# A cached report stands in for the endpoint. Freshly written, so nothing reaches for
# the network to replace it -- which is what makes this test offline by construction.
cat >"$sandbox/run/desktop/claude-usage.json" <<'JSON'
{
  "limits": [
    {"kind": "session", "percent": 26, "resets_at": "2099-01-02T11:00:00+00:00", "severity": "normal"},
    {"kind": "weekly_all", "percent": 70, "resets_at": "2099-01-03T11:00:00+00:00", "severity": "normal"}
  ],
  "spend": {
    "enabled": true, "percent": 94, "severity": "critical",
    "used": {"amount_minor": 5642, "currency": "EUR", "exponent": 2},
    "limit": {"amount_minor": 6000, "currency": "EUR", "exponent": 2}
  }
}
JSON

reported=$(XDG_RUNTIME_DIR="$sandbox/run" CLAUDE_CONFIG_DIR="$sandbox/config" XDG_CACHE_HOME="$sandbox/cache" \
  python3 "$ROOT/bin/desktop-status-claude")

if jq -e . >/dev/null 2>&1 <<<"$reported"; then
  pass "the usage module prints parseable JSON"
else
  fail "the usage module prints parseable JSON" "$reported"
fi

check "the headline is the fullest plan limit" \
  test "$(jq -r .text <<<"$reported")" = "70%"

# 94% of a spending cap is worth a red module and a line in the tooltip. It is not worth
# the headline: "94%" on the bar would be read as tokens, because everything else is.
check "the spending cap colours the module" \
  test "$(jq -r .class <<<"$reported")" = "critical"
check "the spending cap explains itself in the tooltip" \
  grep -q "Extra usage 94% (€56.42 of €60.00)" <<<"$(jq -r .tooltip <<<"$reported")"

check "every limit says when it resets" \
  grep -q "Session 26% -- resets " <<<"$(jq -r .tooltip <<<"$reported")"

# A reset less than a day out is a countdown rather than a clock time, which is the half
# of that formatting with somewhere to go wrong.
python3 - "$sandbox/run/desktop/claude-usage.json" <<'FIXTURE'
import json, sys
from datetime import datetime, timedelta, timezone
path = sys.argv[1]
report = json.load(open(path))
soon = datetime.now(timezone.utc) + timedelta(hours=2, minutes=15, seconds=30)
report["limits"][0]["resets_at"] = soon.isoformat()
json.dump(report, open(path, "w"))
FIXTURE
soon=$(XDG_RUNTIME_DIR="$sandbox/run" CLAUDE_CONFIG_DIR="$sandbox/config" XDG_CACHE_HOME="$sandbox/cache" \
  python3 "$ROOT/bin/desktop-status-claude" | jq -r .tooltip)
check "a reset inside the day counts down" grep -q "Session 26% -- resets in 2h15m" <<<"$soon"

# Nothing cached, no credentials, no transcripts: a fresh machine, or one that has been
# offline since the cache expired.
bare=$(XDG_RUNTIME_DIR="$sandbox/empty" CLAUDE_CONFIG_DIR="$sandbox/config" XDG_CACHE_HOME="$sandbox/cache" \
  python3 "$ROOT/bin/desktop-status-claude")
check "nothing to report renders nothing" test "$(jq -r '.text + .class' <<<"$bare")" = "idle"

# The panel binds straight to these fields, and a binding to a field that stopped being
# emitted renders as an empty row rather than as an error -- so the shape is the
# contract, not just the values.
detail=$(XDG_RUNTIME_DIR="$sandbox/run" CLAUDE_CONFIG_DIR="$sandbox/config" XDG_CACHE_HOME="$sandbox/cache" \
  python3 "$ROOT/bin/desktop-status-claude" --report)

missing=$(jq -r '
  [ (has("plan") | not | select(.) | "plan"),
    (has("limits") | not | select(.) | "limits"),
    (has("spend") | not | select(.) | "spend"),
    (has("tokens") | not | select(.) | "tokens"),
    (has("available") | not | select(.) | "available"),
    (.limits[0] | [ (has("name")|not|select(.)|"limits[].name"),
                    (has("percent")|not|select(.)|"limits[].percent"),
                    (has("resets")|not|select(.)|"limits[].resets"),
                    (has("severity")|not|select(.)|"limits[].severity") ] ),
    (.tokens | [ (has("in")|not|select(.)|"tokens.in"),
                 (has("out")|not|select(.)|"tokens.out"),
                 (has("cached")|not|select(.)|"tokens.cached"),
                 (has("sessions")|not|select(.)|"tokens.sessions") ] )
  ] | flatten | join(" ")' <<<"$detail")
if [[ -z $missing ]]; then
  pass "--report carries every field the panel binds to"
else
  fail "--report carries every field the panel binds to" "$missing"
fi

check "--report keeps the percentages as numbers" \
  test "$(jq -r '.limits[0].percent | type' <<<"$detail")" = "number"

# The agent count, with pgrep stubbed so the answer does not depend on what the machine
# happens to be running. The separator earned a check: `paste -sd', '` reads its
# delimiter as a list to cycle through, so three agents came out "a,b c".
cat >"$sandbox/bin/pgrep" <<'STUB'
#!/usr/bin/env bash
case "${*: -1}" in
claude) echo 4 ;;
opencode) echo 1 ;;
codex) echo 2 ;;
esac
STUB
chmod +x "$sandbox/bin/pgrep"
counted=$(PATH="$sandbox/bin:$PATH" bash "$ROOT/bin/desktop-status-agents")
check "every agent this desktop runs is counted" test "$(jq -r .text <<<"$counted")" = 7
check "the agents are listed one per comma" \
  test "$(jq -r .tooltip <<<"$counted")" = "4 claude, 1 opencode, 2 codex"

cat >"$sandbox/bin/pgrep" <<'STUB'
#!/usr/bin/env bash
exit 1
STUB
chmod +x "$sandbox/bin/pgrep"
quiet=$(PATH="$sandbox/bin:$PATH" bash "$ROOT/bin/desktop-status-agents")
check "no agents running says so" test "$(jq -r .class <<<"$quiet")" = idle
rm "$sandbox/bin/pgrep"

# The composition. Both halves are stubbed, because the real ones answer differently
# depending on what happens to be running while the suite runs.
cat >"$sandbox/bin/desktop-status-agents" <<'STUB'
#!/usr/bin/env bash
echo '{"text":"2","class":"busy","tooltip":"2 claude"}'
STUB
cat >"$sandbox/bin/desktop-status-claude" <<'STUB'
#!/usr/bin/env bash
echo '{"text":"95%","class":"critical","tooltip":"Weekly 95%"}'
STUB
chmod +x "$sandbox/bin"/*

composed=$(PATH="$sandbox/bin:$PATH" bash "$ROOT/bin/desktop-status-ai")
check "both halves reach the bar" test "$(jq -r .text <<<"$composed")" = "2 · 95%"
check "a critical limit outranks a running agent" \
  test "$(jq -r .class <<<"$composed")" = "critical"

# The reason the waiting count is a badge and not a class: with the limit critical the class
# is taken, and the badge has to come through anyway.
cat >"$sandbox/bin/desktop-status-agents" <<'STUB'
#!/usr/bin/env bash
echo '{"text":"2","badge":"1 waiting","class":"waiting","tooltip":"1 waiting for you -- 2 claude"}'
STUB
composed=$(PATH="$sandbox/bin:$PATH" bash "$ROOT/bin/desktop-status-ai")
check "a waiting session is still announced while the limit has the colour" \
  test "$(jq -r '"\(.class) \(.badge)"' <<<"$composed")" = "critical 1 waiting"
cat >"$sandbox/bin/desktop-status-agents" <<'STUB'
#!/usr/bin/env bash
echo '{"text":"2","class":"busy","tooltip":"2 claude"}'
STUB

cat >"$sandbox/bin/desktop-status-claude" <<'STUB'
#!/usr/bin/env bash
echo '{"text":"12%","class":"active","tooltip":"Weekly 12%"}'
STUB
composed=$(PATH="$sandbox/bin:$PATH" bash "$ROOT/bin/desktop-status-ai")
check "an ordinary reading leaves the agent colour alone" \
  test "$(jq -r .class <<<"$composed")" = "busy"
finish
