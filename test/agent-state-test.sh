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

# Nothing here may reach the real tmux server or put a real notification on the screen.
# The suite is usually run from inside tmux, so TMUX is cleared rather than inherited, and
# the commands a notification needs are stubbed to leave a record instead.
unset TMUX TMUX_PANE
stubs="$sandbox/stubs"
mkdir -p "$stubs"
cat >"$stubs/notify-send" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$NOTIFY_LOG"
# Clicked, as far as desktop-agent-state can tell.
[[ $* == *--wait* ]] && echo default
exit 0
STUB
cat >"$stubs/hyprctl" <<'STUB'
#!/usr/bin/env bash
printf '{"pid":%s}\n' "${ACTIVE_WINDOW_PID:-1}"
STUB
cat >"$stubs/jump" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$JUMP_LOG"
STUB
chmod +x "$stubs"/*
export PATH="$stubs:$PATH" NOTIFY_LOG="$sandbox/notify.log" JUMP_LOG="$sandbox/jump.log"
export DESKTOP_AGENT_JUMP="$stubs/jump"
: >"$NOTIFY_LOG"; : >"$JUMP_LOG"

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
mkdir -p "$sandbox/barstubs"
printf '#!/usr/bin/env bash\n[[ "${*: -1}" == claude ]] && echo 2 || echo 0\n' >"$sandbox/barstubs/pgrep"
chmod +x "$sandbox/barstubs/pgrep"
bar=$(PATH="$sandbox/barstubs:$ROOT/bin:$PATH" bash "$ROOT/bin/desktop-status-agents")
check "the bar turns to waiting while a session waits on you" test "$(jq -r .class <<<"$bar")" = waiting
rm -f "$records"/s3.json
bar=$(PATH="$sandbox/barstubs:$ROOT/bin:$PATH" bash "$ROOT/bin/desktop-status-agents")
check "and back to busy once nothing is" test "$(jq -r .class <<<"$bar")" = busy

# --- the tab, the notification, and whether you are already looking
if require tmux; then
  server="agentstate-tab-$$"
  tmux -L "$server" -f /dev/null new-session -d -s work -n editor -x 120 -y 30
  tmux -L "$server" new-window -t work: -n agent
  socket=$(tmux -L "$server" display-message -p '#{socket_path}')
  agent_pane=$(tmux -L "$server" display-message -p -t work:agent '#{pane_id}')
  tab() { tmux -L "$server" show-options -wv -t work:agent @agent_state 2>/dev/null; }
  on_tab() { # <payload>: a hook run from inside the agent's pane
    printf '%s' "$1" | TMUX="$socket,1,0" TMUX_PANE="$agent_pane" DESKTOP_AGENT_PID="$claude_pid" bash "$STATE"
  }
  tab_event() { # <event> [extra json]
    on_tab "{\"hook_event_name\":\"$1\",\"session_id\":\"tab\",\"cwd\":\"/home/someone/archive\"${2:+,$2}}"
  }
  notified() { # waits for a detached notification to land
    local i
    for ((i = 0; i < 30; i++)); do grep -q "$1" "$NOTIFY_LOG" 2>/dev/null && return 0; sleep 0.1; done
    return 1
  }

  tab_event UserPromptSubmit
  check "the agent's tab says working" test "$(tab)" = working

  # Not looking: no client attached, so a permission prompt is worth a notification.
  : >"$NOTIFY_LOG"
  tab_event Notification '"notification_type":"permission_prompt","message":"Claude needs your permission to use Bash"'
  check "the tab says waiting" test "$(tab)" = waiting
  check "waiting sends a notification naming the project and what it wants" \
    notified "archive needs you Claude needs your permission to use Bash"
  for ((i = 0; i < 30; i++)); do [[ -s $JUMP_LOG ]] && break; sleep 0.1; done
  check "clicking it jumps to the agent's pane, on its own server" \
    grep -qx -- "--jump work:1.0 $socket" "$JUMP_LOG"

  # A short turn ends: done on the tab, but not worth a notification.
  tab_event PostToolUse
  : >"$NOTIFY_LOG"
  tab_event Stop
  check "a finished turn marks the tab done" test "$(tab)" = done
  sleep 0.5
  check "a short turn is not worth a notification" test ! -s "$NOTIFY_LOG"

  # A long one is. The turn began before a permission prompt in the middle of it, and the
  # length reported is the whole turn, not the part after the prompt.
  tab_event UserPromptSubmit
  jq -c '.turn -= 600 | .since -= 600' "$records/tab.json" >"$records/tab.tmp" && mv "$records/tab.tmp" "$records/tab.json"
  tab_event Notification '"notification_type":"permission_prompt"'
  tab_event PostToolUse
  : >"$NOTIFY_LOG"
  tab_event Stop
  check "a long turn sends a done notification with the whole turn's length" \
    notified "archive is done Finished after 10m"

  # Claude's idle reminder a minute later is not a second notification.
  tab_event UserPromptSubmit
  jq -c '.turn -= 600' "$records/tab.json" >"$records/tab.tmp" && mv "$records/tab.tmp" "$records/tab.json"
  : >"$NOTIFY_LOG"
  tab_event Notification '"notification_type":"idle_prompt"'
  sleep 0.5
  check "the idle reminder sends nothing" test ! -s "$NOTIFY_LOG"

  # Arriving at the window clears done, once the tmux.conf hook is in place.
  tmux -L "$server" set-hook -g session-window-changed \
    "$(sed -n "s/^set-hook -g session-window-changed '\(.*\)'$/\1/p" "$ROOT/config/tmux/tmux.conf")"
  # From another window: selecting the window already showing changes nothing, and fires
  # nothing either.
  tmux -L "$server" select-window -t work:editor
  tmux -L "$server" select-window -t work:agent
  sleep 0.3
  check "visiting the window clears done" test -z "$(tab)"
  tmux -L "$server" select-window -t work:editor

  # Now looking: a terminal attached to this session, showing the agent's window, focused.
  tmux -L "$server" select-window -t work:agent
  # A real attached client needs a terminal. util-linux's `script` would give it one, but is
  # not installed everywhere and a skipped block reads exactly like a passing one, so a pty
  # from python instead -- already required above. The client is this process's child, which
  # is the shape desktop-agent-state walks up from: client, then the terminal drawing it.
  python3 -c '
import os, sys, time
pid, fd = os.forkpty()
if pid == 0:
    os.environ["TERM"] = "xterm-256color"
    os.execvp("tmux", ["tmux", "-L", sys.argv[1], "attach", "-t", "work"])
while True:
    try:
        os.read(fd, 65536)
    except OSError:
        time.sleep(0.2)
' "$server" >/dev/null 2>&1 &
  viewer=$!
  for ((i = 0; i < 30; i++)); do
    [[ -n $(tmux -L "$server" list-clients -F '#{client_pid}') ]] && break
    sleep 0.1
  done
  export ACTIVE_WINDOW_PID=$viewer

  tab_event UserPromptSubmit
  jq -c '.turn -= 600' "$records/tab.json" >"$records/tab.tmp" && mv "$records/tab.tmp" "$records/tab.json"
  : >"$NOTIFY_LOG"
  tab_event Stop
  sleep 0.5
  check "a turn that ends while you watch sends nothing, however long it ran" test ! -s "$NOTIFY_LOG"
  check "and leaves no done mark, because you have seen it" test -z "$(tab)"

  tab_event UserPromptSubmit
  : >"$NOTIFY_LOG"
  tab_event Notification '"notification_type":"permission_prompt"'
  sleep 0.5
  check "a prompt in front of you sends nothing either" test ! -s "$NOTIFY_LOG"
  check "but still marks the tab, since it waits until answered" test "$(tab)" = waiting

  # Focus elsewhere -- another window is focused, though the client is still attached.
  export ACTIVE_WINDOW_PID=1
  tab_event PostToolUse
  : >"$NOTIFY_LOG"
  tab_event Notification '"notification_type":"permission_prompt"'
  check "with the terminal not focused, you are not looking" notified "archive needs you"
  unset ACTIVE_WINDOW_PID

  tab_event SessionEnd
  check "a session that ends takes its mark off the tab" test -z "$(tab)"

  kill "$viewer" 2>/dev/null
  tmux -L "$server" kill-server 2>/dev/null
  rm -f "$socket"
fi

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
check "the retired notification hook is taken out" lacks desktop-agent-notify <<<"$settings"
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
