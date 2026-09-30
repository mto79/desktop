#!/usr/bin/env bash
# desktop-tmux-sidebar: the column of sessions, what it draws and what it does to tmux.
#
# The drawing has to agree with the tabs -- the same marks, the same agent state -- and it
# has to leave out agents on another tmux server, whose session names mean nothing here.
# The commands matter more: switching must name the client, because one run from inside a
# pane has none and tmux would move a different one; the hook that gives new windows a
# column must sit in a slot of its own, or turning the sidebar off would take the tabs'
# hooks with it.
source "$(dirname "$0")/lib.sh"

require python3 || finish

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
mkdir -p "$sandbox/path"

# A tmux that answers the questions the sidebar asks and writes down the rest, so a check
# can say what it did as well as what it drew.
cat >"$sandbox/path/tmux" <<'STUB'
#!/usr/bin/env bash
args="$*"
case "$args" in
*socket_path*) echo "/tmp/here" ;;
*list-windows*window_name*)
  printf 'alpha\t1\tfish\t\n'
  printf 'alpha\t2\tclaude\tworking\n'
  printf 'beta\t1\tclaude\t\n'
  ;;
*list-windows*)
  printf 'alpha:1\nalpha:2\nbeta:1\n'
  ;;
*list-panes*-a*)
  # $SANDBOX/on is this tmux having columns open, which is what the toggle turns on.
  [[ -e $SANDBOX/on ]] && printf '%%1\t1\n%%2\t\n%%3\t1\n'
  ;;
*list-panes*)
  [[ -e $SANDBOX/on ]] && echo 1
  echo
  ;;
*list-clients*) echo "1790000000 /dev/pts/9" ;;
*split-window*) echo "%9" ;;
esac
echo "$args" >>"$SANDBOX/did"
STUB

# One agent on this server and one on another, which must not be listed.
cat >"$sandbox/path/desktop-agent-sessions" <<'STUB'
#!/usr/bin/env bash
cat <<'JSON'
{"sessions": [
  {"state": "waiting", "for": "3m", "socket": "/tmp/here", "target": "beta:1.2"},
  {"state": "waiting", "for": "9m", "socket": "/tmp/elsewhere", "target": "alpha:1.2"}
]}
JSON
STUB
chmod +x "$sandbox/path/tmux" "$sandbox/path/desktop-agent-sessions"

# The script is loaded rather than run: its drawing and its tmux commands are what is
# being checked, and a curses screen needs a terminal no test has.
cat >"$sandbox/drive.py" <<'DRIVER'
import importlib.machinery, importlib.util, sys

loader = importlib.machinery.SourceFileLoader("sidebar", sys.argv[1])
spec = importlib.util.spec_from_loader("sidebar", loader)
sidebar = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sidebar)
# Colours belong to a screen that was never started; only the text is under test.
sidebar.curses.color_pair = lambda pair: 0

if sys.argv[2] == "rows":
    for row in sidebar.rows("alpha:2"):
        print(sidebar.line_of(row, 30)[0].rstrip())
elif sys.argv[2] == "go":
    sidebar.go({"kind": "window", "session": "beta", "index": "1"}, "alpha:2")
elif sys.argv[2] == "attach":
    sidebar.attach("alpha:2")
elif sys.argv[2] == "toggle":
    sidebar.toggle()
DRIVER

drive() {
  env -i PATH="$sandbox/path:/usr/bin:/bin" HOME=/home/u SANDBOX="$sandbox" TERM=dumb \
    python3 "$sandbox/drive.py" "$ROOT/bin/desktop-tmux-sidebar" "$1" 2>&1
}

# --- what it draws -------------------------------------------------------------------------

drawn=$(drive rows)

check "every session is drawn with its windows under it, in order" \
  test "$(grep -c . <<<"$drawn")" = 5
check "the window you are in is marked" grep -q '^▸ *· claude$' <<<"$drawn"
check "an agent waiting shows on its window and counts on its session" \
  grep -q '^ beta  ●1$' <<<"$drawn"
check "how long it has been waiting is drawn on the right" grep -q '● claude *3m$' <<<"$drawn"
check "an agent on another tmux server is left out of this one's windows" \
  lacks '9m' <<<"$drawn"

# --- what it does --------------------------------------------------------------------------

: >"$sandbox/did"
drive go >/dev/null
check "the window is selected before the session, so it is one jump" \
  test "$(grep -c -m1 'select-window -t beta:1' "$sandbox/did")" = 1
check "the client is switched by name, not left to tmux to guess" \
  grep -q 'switch-client -c /dev/pts/9 -t beta' "$sandbox/did"

: >"$sandbox/did"
drive toggle >/dev/null
check "a column is opened in every window" \
  test "$(grep -c 'split-window' "$sandbox/did")" = 3
check "it spans the window and leaves the cursor where it was" \
  grep -q 'split-window -t alpha:1 -fhbd -l 30' "$sandbox/did"
check "new windows get one too" grep -q 'set-hook -g after-new-window\[50\] ' "$sandbox/did"
check "in a slot of its own, so the tabs' hooks on the same event survive" \
  lacks 'set-hook -g after-new-window ' "$sandbox/did"

touch "$sandbox/on"
: >"$sandbox/did"
drive attach >/dev/null
check "a window that has a column is not given a second" lacks 'split-window' "$sandbox/did"

: >"$sandbox/did"
drive toggle >/dev/null
check "turning it off closes every column" \
  test "$(grep -c 'kill-pane' "$sandbox/did")" = 2
check "and removes only its own hook" grep -q 'set-hook -gu after-new-window\[50\]' "$sandbox/did"

finish
