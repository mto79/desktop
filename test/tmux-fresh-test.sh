#!/usr/bin/env bash
# A clean slate in tmux: every session closed, and nothing left for the next login to
# build again. Killing the server alone left desktop-tmux-restore's picture behind, and
# the morning after brought every session back.
#
# Against a tmux server on a socket of its own, in a sandboxed HOME.
source "$(dirname "$0")/lib.sh"

require tmux || finish

TMUX_BIN=$(command -v tmux)
SOCKET="desktop-fresh-test-$$"
FRESH="$ROOT/bin/desktop-tmux-fresh"

sandbox=$(mktemp -d)
trap '"$TMUX_BIN" -L "$SOCKET" kill-server 2>/dev/null; rm -rf "$sandbox"' EXIT

mkdir -p "$sandbox/bin" "$sandbox/state/desktop/tmux"
cat >"$sandbox/bin/tmux" <<STUB
#!/usr/bin/env bash
exec "$TMUX_BIN" -L "$SOCKET" "\$@"
STUB
chmod +x "$sandbox/bin/tmux"
export HOME="$sandbox" XDG_STATE_HOME="$sandbox/state" PATH="$sandbox/bin:$PATH"
unset TMUX
snapshot="$sandbox/state/desktop/tmux/last.json"

"$TMUX_BIN" -L "$SOCKET" -f /dev/null new-session -d -s one
"$TMUX_BIN" -L "$SOCKET" new-session -d -s two
echo '{"sessions": [{"name": "one"}]}' >"$snapshot"

check "without a yes it changes nothing" bash -c "! '$FRESH' <<<n >/dev/null"
check "and the sessions are still there" "$TMUX_BIN" -L "$SOCKET" has-session -t two
check "nor is the picture forgotten" test -e "$snapshot"

"$FRESH" -y
check "every session is closed" bash -c "! '$TMUX_BIN' -L '$SOCKET' has-session 2>/dev/null"
check "and nothing is left for the next login to restore" test ! -e "$snapshot"
check "with no tmux running it is still a clean slate" "$FRESH" -y

# Run from a pane, the shell running it is one of the things killed. The kill has to come
# from a process that does not die with the pane, or the server outlives it.
echo '{"sessions": []}' >"$snapshot"
"$TMUX_BIN" -L "$SOCKET" -f /dev/null new-session -d -s inside "sleep 1; '$FRESH' -y; sleep 30"
"$TMUX_BIN" -L "$SOCKET" new-session -d -s other
gone=false
for _ in $(seq 50); do
  "$TMUX_BIN" -L "$SOCKET" has-session 2>/dev/null || { gone=true; break; }
  sleep 0.1
done
check "run from inside tmux, it closes the tmux it runs in" test "$gone" = true
check "and forgets that too" test ! -e "$snapshot"

finish
