#!/usr/bin/env bash
# codex and opencode, reported as Claude Code is, and asking before they touch a cluster.
#
# codex calls desktop-agent-state from hooks.json with Claude Code's JSON and two events of its
# own; opencode has a plugin that sends the same JSON. desktop-agent-hooks writes both, and
# tells each agent the cluster guard's list in its own words: codex rules, opencode
# permissions. What is checked is that each reaches the same records, and that the files of
# the user's own it edits keep what was in them -- and keep the cluster rules last, since
# opencode takes the last rule that matches.
source "$(dirname "$0")/lib.sh"

require jq || finish
require python3 || finish

STATE="$ROOT/bin/desktop-agent-state"
SESSIONS="$ROOT/bin/desktop-agent-sessions"
HOOKS="$ROOT/bin/desktop-agent-hooks"

sandbox=$(mktemp -d)
pids=()
cleanup() {
  ((${#pids[@]})) && kill "${pids[@]}" 2>/dev/null
  rm -rf "$sandbox"
}
trap cleanup EXIT

export XDG_RUNTIME_DIR="$sandbox/run"
records="$XDG_RUNTIME_DIR/desktop/agents"
unset TMUX TMUX_PANE CODEX_HOME
stubs="$sandbox/stubs"
mkdir -p "$stubs" "$sandbox/bin"
for cmd in notify-send desktop-shell desktop-say; do printf '#!/usr/bin/env bash\nexit 0\n' >"$stubs/$cmd"; done
chmod +x "$stubs"/*
export PATH="$stubs:$PATH"

# Real processes with the agents' names, for the reader's liveness check.
cp "$(command -v sleep)" "$sandbox/bin/codex"
cp "$(command -v sleep)" "$sandbox/bin/opencode"
"$sandbox/bin/codex" 300 &
codex_pid=$!
"$sandbox/bin/opencode" 300 &
opencode_pid=$!
pids+=("$codex_pid" "$opencode_pid")

event() { # <agent> <event> [extra json]
  local pid=$codex_pid
  [[ $1 == opencode ]] && pid=$opencode_pid
  printf '{"hook_event_name":"%s","session_id":"%s-1","cwd":"/home/u/proj"%s}' "$2" "$1" "${3:+,$3}" |
    DESKTOP_AGENT_KIND="$1" DESKTOP_AGENT_PID="$pid" bash "$STATE"
}
field() { jq -r ".$2" "$records/$1.json" 2>/dev/null; }

# --- codex's events -------------------------------------------------------------------------
event codex SessionStart
check "a codex session is recorded as codex's" test "$(field codex-1 agent)" = codex
check "with its own process" test "$(field codex-1 pid)" = "$codex_pid"
event codex UserPromptSubmit '"prompt":"tidy the module"'
check "a prompt starts a turn" test "$(field codex-1 state)" = working
event codex PermissionRequest
check "codex's approval prompt is waiting on you" test "$(field codex-1 state)" = waiting
event codex PostToolUse
event codex Interrupt
check "a turn you stopped is not a result to read" test "$(field codex-1 state)" = ready
event codex Stop
check "a finished one is" test "$(field codex-1 state)" = "done"

# Which agent, from the process the hook was started by, when nothing says so.
cp "$(command -v bash)" "$sandbox/bin/codex-shell"
ln -sf "$sandbox/bin/codex-shell" "$sandbox/bin/codex"
printf '{"hook_event_name":"SessionStart","session_id":"codex-2","cwd":"/w"}' >"$sandbox/payload"
"$sandbox/bin/codex" -c "bash '$STATE' <'$sandbox/payload'; true"
check "an agent is known by the process that ran its hook" test "$(field codex-2 agent)" = codex

# --- opencode, through its plugin's JSON ----------------------------------------------------
event opencode SessionStart
event opencode Notification '"notification_type":"permission_prompt"'
check "opencode waiting on a permission is waiting" test "$(field opencode-1 state)" = waiting

listed=$(python3 "$SESSIONS" --json)
check "the reader lists codex and opencode beside Claude" \
  test "$(jq -r '[.sessions[].agent] | sort | unique | join(" ")' <<<"$listed")" = "codex opencode"
kill "$opencode_pid" 2>/dev/null
wait "$opencode_pid" 2>/dev/null
check "an opencode that has gone is gone from the list" \
  test "$(python3 "$SESSIONS" --json | jq '[.sessions[] | select(.agent == "opencode")] | length')" = 0
printf '{"agent":"opencode","session":"opencode-9","state":"working","since":1,"turn":1,"pid":%s}' "$codex_pid" \
  >"$records/opencode-9.json"
check "and a record whose pid is now another agent's does not come back to life" \
  test "$(python3 "$SESSIONS" --json | jq '[.sessions[] | select(.session == "opencode-9")] | length')" = 0

# --- the opencode plugin itself, run by node as opencode would ------------------------------
if command -v node >/dev/null 2>&1; then
  home="$sandbox/plugin-home"
  mkdir -p "$home/.local/share/desktop/bin"
  cat >"$home/.local/share/desktop/bin/desktop-agent-state" <<STUB
#!/usr/bin/env bash
{ cat; echo " \$DESKTOP_AGENT_KIND"; } >>"$sandbox/plugin.log"
STUB
  chmod +x "$home/.local/share/desktop/bin/desktop-agent-state"
  cp "$ROOT/config/opencode/plugin/desktop-agent-state.js" "$sandbox/plugin.mjs"
  HOME="$home" node --input-type=module -e "
    const { DesktopAgentState } = await import('$sandbox/plugin.mjs');
    const hooks = await DesktopAgentState({ directory: '/w/proj' });
    await hooks['chat.message']({}, { parts: [{ type: 'text', text: 'fix the build' }] });
    await hooks.event({ event: { type: 'permission.asked', properties: { permission: 'bash' } } });
    await hooks.event({ event: { type: 'permission.replied', properties: {} } });
    await hooks.event({ event: { type: 'session.idle', properties: {} } });
    await new Promise((done) => setTimeout(done, 500));
  " 2>"$sandbox/node.err"
  sent=$(grep -o '"hook_event_name":"[A-Za-z]*"' "$sandbox/plugin.log" 2>/dev/null | cut -d'"' -f4 | paste -sd' ')
  check "the plugin sends opencode's events as hooks, in order" \
    test "$sent" = "SessionStart UserPromptSubmit Notification PostToolUse Stop"
  check "with what was asked" grep -q '"prompt":"fix the build"' "$sandbox/plugin.log"
  check "and says it is opencode" grep -q ' opencode$' "$sandbox/plugin.log"
  rm "$home/.local/share/desktop/bin/desktop-agent-state"
  HOME="$home" node --input-type=module -e "
    const { DesktopAgentState } = await import('$sandbox/plugin.mjs');
    const hooks = await DesktopAgentState({ directory: '/w' });
    await hooks.event({ event: { type: 'session.idle' } });
  " 2>"$sandbox/node.err"
  check "with desktop-agent-state missing, opencode is not disturbed" test ! -s "$sandbox/node.err"
fi

# --- desktop-agent-hooks, for codex and opencode --------------------------------------------
home="$sandbox/home"
mkdir -p "$home/.codex" "$home/.config/opencode" "$home/.claude"
echo '{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"mine"}]}]}}' >"$home/.codex/hooks.json"
echo '{"theme":"system","permission":{"bash":{"*":"allow","helm *":"allow"}}}' >"$home/.config/opencode/opencode.json"
# shellcheck disable=SC2120 # called with --check, through check
wire() { env -u XDG_CONFIG_HOME HOME="$home" CLAUDE_CONFIG_DIR="$home/.claude" bash "$HOOKS" "$@" >/dev/null 2>&1; }
wire
wire
codex_hooks=$(cat "$home/.codex/hooks.json")
check "codex's every event is wired, once" \
  test "$(jq '[.hooks[][].hooks[] | select(.command | contains("desktop-agent-state"))] | length' <<<"$codex_hooks")" = 7
check "with PermissionRequest and Interrupt among them" \
  test "$(jq -r '[.hooks.PermissionRequest, .hooks.Interrupt] | map(length) | join(" ")' <<<"$codex_hooks")" = "1 1"
check "a hook of codex's own is kept" test "$(jq -r '.hooks.Stop[0].hooks[0].command' <<<"$codex_hooks")" = mine
check "codex is not given the guard, whose ask it would ignore" lacks cluster-guard <<<"$codex_hooks"
rules="$home/.codex/rules/desktop-clusters.rules"
check "codex's rules ask about every tool on the guard's list" \
  test "$(grep -c 'decision="prompt"' "$rules")" = "$(bash "$ROOT/bin/desktop-agent-cluster-guard" --tools | wc -l)"
check "kubectl among them" grep -qx 'prefix_rule(pattern=\["kubectl"\], decision="prompt", justification="reaches a Kubernetes cluster")' "$rules"

config=$(cat "$home/.config/opencode/opencode.json")
keys=$(jq -r '.permission.bash | keys_unsorted | join(" ")' <<<"$config")
check "opencode asks about kubectl, with and without arguments" \
  test "$(jq -r '.permission.bash["kubectl *"] + " " + .permission.bash.kubectl' <<<"$config")" = "ask ask"
check "after a catch-all of your own, since opencode takes the last rule that matches" \
  test "${keys%% *}" = "*"
check "a value of your own for the same pattern is kept" test "$(jq -r '.permission.bash["helm *"]' <<<"$config")" = allow
check "and the rest of the file is left" test "$(jq -r .theme <<<"$config")" = system
check "the plugin is put where opencode loads it" \
  cmp -s "$ROOT/config/opencode/plugin/desktop-agent-state.js" "$home/.config/opencode/plugin/desktop-agent-state.js"
check "run again it changes nothing" wire --check

echo '{"permission":"ask"}' >"$home/.config/opencode/opencode.json"
wire
check "an opencode that asks about everything already is left so" \
  test "$(jq -c .permission "$home/.config/opencode/opencode.json")" = '"ask"'
printf '{ broken' >"$home/.codex/hooks.json"
wire
check "a codex hooks file that does not parse is left alone" test "$(cat "$home/.codex/hooks.json")" = "{ broken"

rm -rf "$home/.codex" "$home/.config/opencode"
env -u XDG_CONFIG_HOME HOME="$home" CLAUDE_CONFIG_DIR="$home/.claude" PATH="$stubs:/usr/bin:/bin" bash "$HOOKS" >/dev/null 2>&1
check "with neither installed, neither is set up" test ! -e "$home/.codex" -a ! -e "$home/.config/opencode"

finish
