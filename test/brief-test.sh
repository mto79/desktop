#!/usr/bin/env bash
# The brief: what needs you, gathered from everything that keeps track of something, and
# the dashboard that shows it. Every source is a stub or a fixture file; what is checked is
# that their answers arrive side by side, that the one number for "how much wants doing"
# counts the right things, and that a source which is missing or broken costs its own
# section and not the brief.
source "$(dirname "$0")/lib.sh"

require jq || finish

BRIEF="$ROOT/bin/desktop-brief"
sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
stubs="$sandbox/stubs"
mkdir -p "$stubs" "$sandbox/state/desktop/security" "$sandbox/run"

stub() { printf '#!/usr/bin/env bash\ncat <<'"'"'JSON'"'"'\n%s\nJSON\n' "$2" >"$stubs/$1"; chmod +x "$stubs/$1"; }
stub desktop-backup '{"text":"","class":"stale","tooltip":"Last backup 9 days ago\nmore"}'
stub desktop-worktree '{"tasks":[{"repo":"gitops","name":"fix-runner","ahead":2,"dirty":1,"state":"waiting","target":"gitops:3.1","path":"/x"}]}'
stub desktop-agent-sessions '{"waiting":1,"sessions":[{"project":"gitops","state":"waiting","for":"4m","target":"a:1.1","socket":"/s"},{"project":"desktop","state":"working","for":"1m","target":"b:1.1","socket":"/s"},{"project":"wiki","state":"done","for":"9m","target":"","socket":""}]}'
stub desktop-status-claude '{"plan":"pro","limits":[{"name":"Session","percent":40,"resets":"in 3h"},{"name":"Weekly","percent":91,"resets":"Fri 13:00"}]}'
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >>"%s/said"\n' "$sandbox" >"$stubs/desktop-say"
chmod +x "$stubs/desktop-say"

echo '{"checked":1,"sources":[{"id":"firmware","count":3,"label":"firmware updates"},{"id":"dnf","count":12,"label":"packages"}]}' >"$sandbox/run/desktop-update-available.json"
echo '{"at":2,"findings":[{"level":"bad","title":"sshd accepts passwords"},{"level":"warn","title":"Secure Boot is off"},{"level":"info","title":"checked the firewall"}]}' >"$sandbox/state/desktop/security/last.json"
echo '[{"app":"Brave","summary":"one"},{"app":"Updates","summary":"two"}]' >"$sandbox/state/desktop/notifications.json"
touch "$sandbox/state/desktop/reboot-required"

run() { PATH="$stubs:$PATH" XDG_STATE_HOME="$sandbox/state" XDG_RUNTIME_DIR="$sandbox/run" bash "$BRIEF" "$@"; }
all=$(run --json)

check "updates are added up across where they come from" test "$(jq .updates.count <<<"$all")" = 15
check "security findings are listed without the check's own notes" \
  test "$(jq -r '[.security.findings[].title] | join("|")' <<<"$all")" = "sshd accepts passwords|Secure Boot is off"
check "and the bad ones are counted" test "$(jq .security.bad <<<"$all")" = 1
check "the backup's state is passed on" test "$(jq -r .backup.state <<<"$all")" = stale
check "tasks come with what the dashboard needs to go to them" \
  test "$(jq -r '.tasks[0] | "\(.repo) \(.name) \(.ahead) \(.target)"' <<<"$all")" = "gitops fix-runner 2 gitops:3.1"
check "agents are counted by what they are doing" \
  test "$(jq -r '.agents | "\(.waiting) \(.working) \(.done)"' <<<"$all")" = "1 1 1"
check "Claude's limits are there" test "$(jq -r '.limits[1] | "\(.name) \(.percent)"' <<<"$all")" = "Weekly 91"
check "a pending restart is noticed" test "$(jq -r '.system.restart_marks[0]' <<<"$all")" = reboot-required
check "kept notifications are counted, newest first" \
  test "$(jq -r '"\(.notifications.kept) \(.notifications.latest[0].summary)"' <<<"$all")" = "2 two"
# A waiting agent, a bad finding, a pending restart and a waiting task: four things.
check "one number says how much wants doing" test "$(jq .attention <<<"$all")" = 4

text=$(run)
check "the short version leads with who is waiting" test "$(head -1 <<<"$text")" = "1 agent is waiting for you"
check "and says singular and plural properly" grep -qx "15 updates are available" <<<"$text"
run --say
check "said out loud, it is a handful of sentences and no more" \
  test "$(grep -o '\.' "$sandbox/said" | wc -l)" = 4

# --- the welcome at login
: >"$sandbox/said"
run --welcome
check "the welcome greets, and says what is waiting" \
  grep -qE '^Good (night|morning|afternoon|evening)(, [A-Z][a-z]+)?\. 1 agent is waiting for you\.' "$sandbox/said"
check "in three things at most" test "$(grep -o '\.' "$sandbox/said" | wc -l)" -le 4
check "the login says it" grep -qx 'desktop-brief --welcome >/dev/null 2>&1 &' "$ROOT/bin/desktop-workspace-start"
check "the dashboard greets by the same name" test "$(jq -r '.user | type' <<<"$all")" = string

# A source that is not there, or prints something that is not JSON, is an empty section.
rm "$stubs/desktop-worktree"
printf '#!/usr/bin/env bash\necho "Traceback: something broke"\nexit 1\n' >"$stubs/desktop-status-claude"
chmod +x "$stubs/desktop-status-claude"
echo 'not json' >"$sandbox/state/desktop/security/last.json"
broken=$(PATH="$stubs:/usr/bin:/bin" XDG_STATE_HOME="$sandbox/state" XDG_RUNTIME_DIR="$sandbox/run" bash "$BRIEF" --json)
check "a broken source costs its own section" \
  test "$(jq -r '"\(.tasks | length) \(.limits | length) \(.security.findings | length)"' <<<"$broken")" = "0 0 0"
check "and not the rest of the brief" test "$(jq .updates.count <<<"$broken")" = 15

rm -rf "$sandbox/state" "$sandbox/run"/* "$stubs"/desktop-{backup,agent-sessions,status-claude}
quiet=$(PATH="$stubs:/usr/bin:/bin" XDG_STATE_HOME="$sandbox/state" XDG_RUNTIME_DIR="$sandbox/run" bash "$BRIEF")
check "with nothing to report it says so" test "$quiet" = "Nothing needs you"

# --- the dashboard
DASH="$ROOT/shell/Dashboard/Dashboard.qml"
# Through desktop-dash, which hands each tab its answer; the start tab's is the brief.
check "the dashboard draws what the brief says" \
  grep -q '^start) desktop-brief --json' "$ROOT/bin/desktop-dash"
check "it is part of the shell" grep -q '^  Dashboard {' "$ROOT/shell/shell.qml"
check "it is a window, so the workspace keys and the overview treat it as one" grep -q 'FloatingWindow {' "$DASH"
check "a rule puts that window on workspace 6, without dragging you there" \
  grep -qxF 'windowrule = workspace 6 silent, match:class ^(org\.quickshell)$, match:title ^(Dashboard)$' \
  "$ROOT/default/hypr/apps/desktop-shell.conf"
check "in the Lua rules as well" grep -q 'title = "^(Dashboard)$" }, workspace = "6 silent"' "$ROOT/default/hypr/apps/desktop-shell.lua"
check "workspace 6 has a screen to be on" grep -qx '  "6 laptop"' "$ROOT/bin/desktop-workspace-pin"
# Every asking is half a dozen commands and git on every task.
check "it only asks again while it is being looked at" \
  test -n "$(sed -n '/interval: 30000/,/onTriggered/p' "$DASH" | grep 'running: root.lookedAt')"
# Looked at means on a screen. It used to mean focused, and with three monitors focus
# follows the pointer: the page emptied when the mouse left the laptop's screen and
# filled again when it came back, in plain view the whole time.
check "and being looked at does not depend on where the pointer is" \
  lacks 'lookedAt:.*focusedWorkspace' "$DASH"

finish
