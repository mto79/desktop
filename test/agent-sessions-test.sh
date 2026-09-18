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
# fzf picks the line naming $PICK, as a person typing it and pressing Enter would.
cat >"$sandbox/path/fzf" <<'STUB'
#!/usr/bin/env bash
grep -m1 "$PICK"
STUB
chmod +x "$sandbox/path/tmux" "$sandbox/path/fzf"

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
check "picking a session switches this tmux to its pane" test "$(cat "$sandbox/switched")" = "switch-client -t beta:1.2"

rm -f "$sandbox/switched"
sessions PICK=other </dev/null >/dev/null 2>&1
check "a session in another tmux server is not switched to here" test ! -e "$sandbox/switched"

finish
