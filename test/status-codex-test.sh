#!/usr/bin/env bash

# desktop-status-codex: Codex's plan limits from the usage endpoint, with the token Codex
# keeps, named by their windows, and none of it asked for with a token that has expired.

source "$(dirname "$0")/lib.sh"

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
mkdir -p "$sandbox/codex" "$sandbox/run"

# A token as Codex keeps one: a JWT whose payload says when it expires.
jwt() { printf 'x.%s.y' "$(printf '{"exp": %s}' "$1" | base64 -w0 | tr '+/' '-_' | tr -d '=')"; }
auth() { printf '{"auth_mode": "chatgpt", "tokens": {"access_token": "%s", "account_id": "acct"}}' "$(jwt "$1")" >"$sandbox/codex/auth.json"; }

now=$(date +%s)
cat >"$sandbox/usage.json" <<EOF
{"plan_type": "plus", "rate_limit": {"limit_reached": false,
  "primary_window": {"used_percent": 42.4, "limit_window_seconds": 18000, "reset_at": $((now + 3600))},
  "secondary_window": {"used_percent": 91, "limit_window_seconds": 604800, "reset_at": $((now + 3 * 86400))}}}
EOF

codex() {
  env -i PATH=/usr/bin:/bin CODEX_HOME="$sandbox/codex" XDG_RUNTIME_DIR="$sandbox/run" \
    DESKTOP_CODEX_USAGE_URL="file://$sandbox/usage.json" python3 "$ROOT/bin/desktop-status-codex"
}

auth $((now + 3600))
out=$(codex)
check "the plan is read" test "$(jq -r .plan <<<"$out")" = plus
check "each window is named by its length, the fullest first" \
  test "$(jq -r '[.limits[].name] | join(" ")' <<<"$out")" = "Weekly Session"
check "  how full, rounded" test "$(jq -r '[.limits[].percent] | join(" ")' <<<"$out")" = "91 42"
check "  and when it resets: inside the day as a countdown" \
  grep -qE '^in (59m|1h00m)$' <<<"$(jq -r '.limits[1].resets' <<<"$out")"
check "a limit past ninety is critical, and so is the whole" \
  test "$(jq -r '"\(.limits[0].severity) \(.severity)"' <<<"$out")" = "critical critical"
check "the answer is kept for the runtime directory's owner alone" \
  test "$(stat -c %a "$sandbox/run/desktop/codex-usage.json")" = 600

echo '{"plan_type": "free", "rate_limit": {"primary_window": {"used_percent": 0, "limit_window_seconds": 2592000, "reset_after_seconds": 2592000}}}' >"$sandbox/usage.json"
rm "$sandbox/run/desktop/codex-usage.json"
out=$(codex)
check "the free plan's thirty days are monthly, with a reset worked out from seconds" \
  test "$(jq -r '.limits[0] | "\(.name) \(.resets != "")"' <<<"$out")" = "Monthly true"

rm "$sandbox/run/desktop/codex-usage.json"
auth $((now - 60))
out=$(codex)
check "an expired token asks nothing, and says limits are unavailable" \
  test "$(jq -r '"\(.available) \(.limits | length)"' <<<"$out")" = "false 0"

check "the AI panel shows Codex's limits" grep -q '"desktop-status-codex"' "$ROOT/shell/Bar/panels/AiPanel.qml"

finish
