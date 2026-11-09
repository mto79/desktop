#!/usr/bin/env bash
# desktop-agent-sessions' two tmux modes: the count in every status bar, and the picker.
#
# The count is what shows an agent waiting in another tmux session -- the tabs only cover
# the session you are in -- so it must count all of them, and say nothing when nothing is
# happening. The picker must land on the pane it names, and must not switch this tmux to a
# target that only exists in another server, where the same name means something else.
source "$(dirname "$0")/lib.sh"

require python3 || finish

sandbox=$(mktemp -d)
trap 'kill $(jobs -p) 2>/dev/null; rm -rf "$sandbox"' EXIT
mkdir -p "$sandbox/path" "$sandbox/runtime/desktop/agents"

# A process whose name is "claude", so the records below count as alive.
ln -s "$(command -v sleep)" "$sandbox/claude"
"$sandbox/claude" 300 &
pid=$!

record() { # name state pane socket
  printf '{"agent":"claude","session":"%s","state":"%s","since":%d,"cwd":"/home/u/%s","pane":"%s","socket":"%s","pid":%d}\n' \
    "$1" "$2" "$(date +%s)" "$1" "$3" "$4" "$pid" >"$sandbox/runtime/desktop/agents/$1.json"
}

cat >"$sandbox/path/tmux" <<'STUB'
#!/usr/bin/env bash
case "$*" in
*show-options*@agent-waiting-colour*) echo "#e06c75" ;;
*display-message*)
  # Joined first: ${*##...} would strip each argument on its own.
  args="$*"
  pane=${args##*-t }
  pane=${pane%% *}
  echo "${pane#%}:1.2" ;;
switch-client*) echo "$*" >>"$SANDBOX/switched" ;;
esac
STUB
# The jump is desktop-agent-tabs' job now -- an agent in an AI column is reached through
# the column, not by switching a client to the narrow session it lives in. What this test
# still owns is that the picker hands over the right pane, and hands over nothing at all
# for a session on another server.
cat >"$sandbox/path/desktop-agent-tabs" <<'STUB'
#!/usr/bin/env bash
[[ $1 == jump ]] && echo "$2" >>"$SANDBOX/jumped"
STUB

# fzf picks the line naming $PICK, as a person typing it and pressing Enter would.
cat >"$sandbox/path/fzf" <<'STUB'
#!/usr/bin/env bash
grep -m1 "$PICK"
STUB
chmod +x "$sandbox/path/tmux" "$sandbox/path/fzf" "$sandbox/path/desktop-agent-tabs"

sessions() {
  env -i PATH="$sandbox/path:/usr/bin:/bin" HOME=/home/u XDG_RUNTIME_DIR="$sandbox/runtime" \
    SANDBOX="$sandbox" TMUX="$sandbox/own-socket,1,0" "$@" python3 "$ROOT/bin/desktop-agent-sessions" "${ARGS[@]}"
}

record alpha waiting %alpha "$sandbox/own-socket"
record beta working %beta "$sandbox/own-socket"
record gamma working %gamma "$sandbox/own-socket"
record delta done %delta "$sandbox/own-socket"

ARGS=(--tmux-status)
check "every waiting and working agent is counted, waiting in the tabs' colour" \
  test "$(sessions)" = "#[fg=#e06c75]● 1 waiting#[default]  · 2 working   "

rm "$sandbox/runtime/desktop/agents/"{alpha,beta,gamma}.json
check "with only finished sessions the status bar says nothing" test -z "$(sessions)"

record beta working %beta "$sandbox/own-socket"
record other waiting %other "$sandbox/another-socket"
ARGS=(--pick)
sessions PICK=beta </dev/null >/dev/null
check "picking a session hands its pane over to be jumped to" \
  test "$(cat "$sandbox/jumped")" = "%beta"

# A task's worktree is named after its branch, so the list says whose task it is.
printf '{"agent":"claude","session":"task","state":"working","since":%d,"cwd":"/home/u/repo.worktrees/fix-runner","pane":"%%task","socket":"%s","pid":%d}\n' \
  "$(date +%s)" "$sandbox/own-socket" "$pid" >"$sandbox/runtime/desktop/agents/task.json"
ARGS=(--json)
check "an agent in a task's worktree is listed by repository and task" \
  test "$(sessions | jq -r '.sessions[] | select(.session == "task") | .project')" = "repo · fix-runner"
check "and any other by its directory" \
  test "$(sessions | jq -r '.sessions[] | select(.session == "beta") | .project')" = "beta"
rm "$sandbox/runtime/desktop/agents/task.json"
ARGS=(--pick)

rm -f "$sandbox/jumped"
sessions PICK=other </dev/null >/dev/null 2>&1
check "a session in another tmux server is not switched to here" test ! -e "$sandbox/jumped"

# --- prefix + N ------------------------------------------------------------------------------

# A tmux that remembers the last pane gone to, says which tab is unread, and writes down
# what it was asked to show.
cat >"$sandbox/path/tmux" <<'STUB'
#!/usr/bin/env bash
args="$*"
case "$args" in
*socket_path*) echo "$SANDBOX/own-socket" ;;
*show-options*@agent_next_last*) cat "$SANDBOX/last" 2>/dev/null ;;
*set-option*@agent_next_last*) echo "${args##* }" >"$SANDBOX/last" ;;
*display-message*-p*)
  pane=${args##*-t }
  pane=${pane%% *}
  # The unread finished turn carries its mark on the tab; the others none.
  [[ $pane == %delta ]] && printf 'delta:1.2\tdone\n' || echo "${pane#%}:1.2" ;;
*display-message*) echo "${args##*display-message }" >>"$SANDBOX/said" ;;
esac
STUB

at() { # name state pane seconds-ago
  printf '{"agent":"claude","session":"%s","state":"%s","since":%d,"cwd":"/home/u/%s","pane":"%s","socket":"%s","pid":%d}\n' \
    "$1" "$2" $(($(date +%s) - $4)) "$1" "$3" "$sandbox/own-socket" "$pid" >"$sandbox/runtime/desktop/agents/$1.json"
}
rm -f "$sandbox/runtime/desktop/agents/"*.json "$sandbox/jumped"
at newer waiting %newer 60
at older waiting %older 600
at delta done %delta 30
at busy working %busy 900
touch -d '-20 minutes' "$sandbox/runtime/desktop/agents/busy.json"
at fine working %fine 900
at far waiting %far 9000
sed -i "s|own-socket|another-socket|" "$sandbox/runtime/desktop/agents/far.json"

ARGS=(--next /dev/pts/9)
for _ in 1 2 3 4 5; do sessions >/dev/null; done
check "it goes to the agent waiting longest first, then the newer, then the unread, then the stuck" \
  test "$(paste -sd' ' "$sandbox/jumped")" = "%older %newer %delta %busy %older"
check "it names the client that pressed it" grep -q '^-c /dev/pts/9 ' "$sandbox/said"
check "and says where it went and how many there are" grep -q ' 1/4  waiting 10m  older$' "$sandbox/said"
check "a stuck agent is said to be stuck" grep -q ' 4/4  stuck .*busy$' "$sandbox/said"
check "an agent on another tmux server is not gone to" lacks '%far' "$sandbox/jumped"
check "nor one busy and heard from" lacks '%fine' "$sandbox/jumped"

rm -f "$sandbox/runtime/desktop/agents/"*.json "$sandbox/said" "$sandbox/jumped"
sessions >/dev/null
check "with nobody needing you it says so and goes nowhere" \
  grep -q 'No agent needs you' "$sandbox/said"
check "and jumps nowhere" test ! -e "$sandbox/jumped"

finish
