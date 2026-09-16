#!/usr/bin/env bash
# What each Claude Code session is doing, as reported by its hooks.
#
# The writer runs inside the agent's own hooks, so it must never fail the agent and must
# stay cheap on the event that fires on every tool call. The reader decides what the panel
# and the bar believe, so it must not show a session that no longer exists: a crash fires
# no SessionEnd, and a pid can be taken by an unrelated process afterwards. The installer
# edits a settings file that holds far more than hooks.
source "$(dirname "$0")/lib.sh"

require jq || finish
require python3 || finish

STATE="$ROOT/bin/desktop-agent-state"
SESSIONS="$ROOT/bin/desktop-agent-sessions"
HOOKS="$ROOT/bin/desktop-agent-hooks"

sandbox=$(mktemp -d)
cleanup() {
  [[ -n ${claude_pid:-} ]] && kill "$claude_pid" 2>/dev/null
  rm -rf "$sandbox"
}
trap cleanup EXIT

export XDG_RUNTIME_DIR="$sandbox/run"
records="$XDG_RUNTIME_DIR/desktop/agents"

# A real process called claude, for the reader's liveness check to find.
mkdir -p "$sandbox/bin"
cp "$(command -v sleep)" "$sandbox/bin/claude"
"$sandbox/bin/claude" 300 &
claude_pid=$!

hook() { # <json payload>
  printf '%s' "$1" | DESKTOP_AGENT_PID="$claude_pid" TMUX_PANE=%9 bash "$STATE"
}
event() { # <event> [extra json fields]
  hook "{\"hook_event_name\":\"$1\",\"session_id\":\"s1\",\"cwd\":\"/home/someone/proj\"${2:+,$2}}"
}
state() { jq -r .state "$records/s1.json" 2>/dev/null; }

# --- the writer
event SessionStart
check "a new session is ready" test "$(state)" = ready
event UserPromptSubmit
check "a prompt makes it working" test "$(state)" = working
event Notification '"notification_type":"permission_prompt"'
check "a permission prompt makes it waiting" test "$(state)" = waiting
check "the project survives a payload with an empty field in the middle" \
  test "$(jq -r .cwd "$records/s1.json")" = /home/someone/proj
check "the pane and the pid are recorded" \
  test "$(jq -r '"\(.pane) \(.pid)"' "$records/s1.json")" = "%9 $claude_pid"
event PostToolUse
check "the tool running after approval makes it working again" test "$(state)" = working

since=$(jq -r .since "$records/s1.json")
sleep 1.1
event PostToolUse
check "another tool call does not reset how long it has been working" \
  test "$(jq -r .since "$records/s1.json")" = "$since"

event Stop
check "the end of a turn makes it done" test "$(state)" = done
event Notification '"notification_type":"auth_success"'
check "a notification that says nothing about you changes nothing" test "$(state)" = done
event UserPromptSubmit
event Notification '"notification_type":"idle_prompt"'
check "the idle reminder marks a session left working after Esc as done" test "$(state)" = done
event Notification
check "a notification with no type, from older Claude Code, means waiting" test "$(state)" = waiting

check "garbage on stdin does not fail the hook" bash -c "printf 'not json' | bash '$STATE'"
hook '{"hook_event_name":"Stop","session_id":"../../etc/x"}'
check "a session id that is not a plain name is never used as a path" \
  test -z "$(find "$XDG_RUNTIME_DIR" -name 'x.json')"

# --- the reader
event Stop
hook '{"hook_event_name":"UserPromptSubmit","session_id":"s2","cwd":"/home/someone/other"}'
hook '{"hook_event_name":"Notification","session_id":"s3","cwd":"/home/someone/third","notification_type":"permission_prompt"}'
listed=$(python3 "$SESSIONS" --json)
check "sessions needing you come first" \
  test "$(jq -r '[.sessions[].state] | join(" ")' <<<"$listed")" = "waiting working done"
check "the counts add up" test "$(jq -r '"\(.waiting) \(.working) \(.done)"' <<<"$listed")" = "1 1 1"

# A crash: the process is gone and no SessionEnd ever came.
printf '{"agent":"claude","session":"crashed","state":"working","since":%s,"cwd":"/x","pane":"","pid":999999}' \
  "$(date +%s)" >"$records/crashed.json"
# A pid taken over by something else -- this shell is alive, but it is not claude.
printf '{"agent":"claude","session":"reused","state":"working","since":%s,"cwd":"/x","pane":"","pid":%s}' \
  "$(date +%s)" "$$" >"$records/reused.json"
python3 "$SESSIONS" --json >/dev/null
check "a session whose process has gone is not shown" test ! -f "$records/crashed.json"
check "nor one whose pid now belongs to something else" test ! -f "$records/reused.json"

# No pid at all can be verified by age only.
printf '{"agent":"claude","session":"nopid","state":"done","since":%s,"cwd":"/x","pane":"","pid":null}' \
  "$(date +%s)" >"$records/nopid.json"
printf '{"agent":"claude","session":"oldnopid","state":"done","since":%s,"cwd":"/x","pane":"","pid":null}' \
  "$(($(date +%s) - 2 * 86400))" >"$records/oldnopid.json"
python3 "$SESSIONS" --json >/dev/null
check "an unverifiable session is kept for the day" test -f "$records/nopid.json"
check "and forgotten after it" test ! -f "$records/oldnopid.json"

# Pane ids only mean something on their own server: every tmux server has a %0. A record
# from one server must be resolved there, never against whichever server happens to be the
# default.
if require tmux; then
  tmux -L "agentstate-a-$$" -f /dev/null new-session -d -s alpha
  tmux -L "agentstate-b-$$" -f /dev/null new-session -d -s beta
  socket_b=$(tmux -L "agentstate-b-$$" display-message -p '#{socket_path}')
  printf '{"agent":"claude","session":"panes","state":"working","since":%s,"cwd":"/x","pane":"%%0","socket":"%s","pid":%s}' \
    "$(date +%s)" "$socket_b" "$claude_pid" >"$records/panes.json"
  target=$(TMUX= python3 "$SESSIONS" --json | jq -r '.sessions[] | select(.session == "panes") | .target')
  check "a pane is resolved on the server it belongs to, not on another with the same id" \
    test "$target" = "beta:0.0"
  tmux -L "agentstate-a-$$" kill-server; tmux -L "agentstate-b-$$" kill-server
  rm -f "${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/agentstate-a-$$" "$socket_b" "$records/panes.json"
fi

event SessionEnd
check "a session that ends cleanly removes its record" test ! -f "$records/s1.json"

# --- the bar
mkdir -p "$sandbox/stubs"
printf '#!/usr/bin/env bash\n[[ "${*: -1}" == claude ]] && echo 2 || echo 0\n' >"$sandbox/stubs/pgrep"
chmod +x "$sandbox/stubs/pgrep"
bar=$(PATH="$sandbox/stubs:$ROOT/bin:$PATH" bash "$ROOT/bin/desktop-status-agents")
check "the bar turns to waiting while a session waits on you" test "$(jq -r .class <<<"$bar")" = waiting
rm -f "$records"/s3.json
bar=$(PATH="$sandbox/stubs:$ROOT/bin:$PATH" bash "$ROOT/bin/desktop-status-agents")
check "and back to busy once nothing is" test "$(jq -r .class <<<"$bar")" = busy

# --- the installer
config="$sandbox/claude"
mkdir -p "$config"
cat >"$config/settings.json" <<'JSON'
{
  "model": "opus",
  "env": {"SOMETHING": "kept"},
  "hooks": {
    "Notification": [{"hooks": [{"type": "command", "command": "$HOME/.local/share/desktop/bin/desktop-agent-notify"}]}],
    "PreToolUse": [{"matcher": "Bash", "hooks": [{"type": "command", "command": "some-guard"}]}]
  }
}
JSON
before=$(jq 'del(.hooks)' "$config/settings.json")
CLAUDE_CONFIG_DIR="$config" bash "$HOOKS" >/dev/null
CLAUDE_CONFIG_DIR="$config" bash "$HOOKS" >/dev/null
settings=$(cat "$config/settings.json")
check "every event is wired" \
  test "$(jq -r '[.hooks | to_entries[] | select([.value[].hooks[].command] | any(contains("desktop-agent-state"))) | .key] | sort | join(" ")' <<<"$settings")" \
  = "Notification PostToolUse SessionEnd SessionStart Stop UserPromptSubmit"
check "running it twice wires nothing twice" \
  test "$(jq '[.hooks[][].hooks[] | select(.command | contains("desktop-agent-state"))] | length' <<<"$settings")" = 6
check "the notification hook already there is kept" grep -q desktop-agent-notify <<<"$settings"
check "an unrelated hook is kept, matcher and all" \
  test "$(jq -r '.hooks.PreToolUse[0].matcher' <<<"$settings")" = Bash
check "everything that is not a hook is left exactly as it was" \
  test "$(jq 'del(.hooks)' <<<"$settings")" = "$before"
check "--check agrees once everything is wired" env CLAUDE_CONFIG_DIR="$config" bash "$HOOKS" --check

printf '{ broken' >"$config/settings.json"
CLAUDE_CONFIG_DIR="$config" bash "$HOOKS" >/dev/null 2>&1
check "a settings file that does not parse is left alone, not replaced" \
  test "$(cat "$config/settings.json")" = "{ broken"

finish
