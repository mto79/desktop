#!/usr/bin/env bash
# desktop-tmux-sidebar: the column of sessions, what it draws and what it does to tmux.
#
# A row per session and nothing else: no windows, and no loose entry for the sessions an
# agent column or a terminal's tabs are made of -- their agents count towards the session
# whose window holds them. The state on a row is that of the agent most in need of you,
# with the same marks as the tabs, and agents on another tmux server are left out.
# The commands matter as much: switching must name the client, because one run from inside
# a pane has none and tmux would move a different one; the hook that gives new windows a
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
*@agent-claude-colour*) printf '#ff9e64\t#a9b1d6\t#7aa2f7\n' ;;
*list-windows*session_path*)
  # session, window, the tab's mark, the marks of an agent column's and of a terminal's
  # tabs, the session's directory, the column's model, its task and the window's name.
  printf 'alpha\t1\t\t\t\t/w/alpha\t\t\tfish\n'
  printf 'alpha\t2\tworking\t\t\t/w/alpha\t\t\tide\n'
  printf 'beta\t1\t\t\t\t/w/beta\t\t\tide\n'
  printf 'gamma\t1\t\t\t\t/w/gamma\t\t\tfish\n'
  printf 'delta\t1\t\t\t\t/w/delta\t\t\tide\n'
  printf 'epsilon\t1\t\t\t\t/w/epsilon\t\t\tide\n'
  # alpha's agent column: two tabs waiting, one working in a task, one finished and unread,
  # and an opencode tab that reports nothing.
  printf 'ai-alpha-2-claude\t1\twaiting\talpha-2\t\t/w/alpha\tclaude\tfix-runner\tclaude\t@21\n'
  printf 'ai-alpha-2-claude\t2\tdone\talpha-2\t\t/w/alpha\tclaude\t\tclaude\t@22\n'
  printf 'ai-alpha-2-claude\t3\twaiting\talpha-2\t\t/w/alpha\tclaude\t\tclaude\t@23\n'
  printf 'ai-alpha-2-opencode\t1\t\talpha-2\t\t/w/alpha\topencode\t\topencode\t@24\t5002\n'
  # With clusters (\$SANDBOX/with-clusters): ocl's session for the lab cluster, marked so.
  [[ -e $SANDBOX/with-clusters ]] && printf 'k8s-lab\t1\t\t\t\t/home/u\t\t\tshell\t@40\t5001\tlab\n'
  # And a view's session, built by desktop-view with the lab cluster.
  [[ -e $SANDBOX/with-clusters ]] && printf 'view-upgrade\t1\t\t\t\t/home/u\t\t\tide\t@41\t5001\tlab\tupgrade\n'
  # A terminal's tabs in alpha, and a column whose window has gone.
  printf 'term-alpha-3\t1\t\t\talpha-3\t/w/alpha\t\t\tfish\n'
  printf 'ai-gone-9-claude\t1\twaiting\tgone-9\t\t/w\tclaude\t\tclaude\n'
  ;;
*display-message*@ai_group*)
  # The session a window is in and the marks of the tabs that live inside a pane.
  case "$args" in
  *ai-alpha-2-claude:1*) printf 'ai-alpha-2-claude\talpha-2\n' ;;
  *term-alpha-3:1*) printf 'term-alpha-3\talpha-3\n' ;;
  *) printf '%s\t\n' "${args#*-t }" | sed 's/:.*\t/\t/; s/ .*\t/\t/' ;;
  esac
  ;;
*list-windows*)
  printf 'alpha:1\nalpha:2\nbeta:1\nai-alpha-2-claude:1\nterm-alpha-3:1\nai-beta-7-claude:1\n'
  ;;
*list-clients*-F*session_name*)
  # What is on screen: two clients on alpha:1, one on beta:1, and the nested clients an
  # agent column and a terminal's tabs are drawn by. alpha:2 is looked at by nobody.
  printf 'alpha:1\nbeta:1\nalpha:1\nai-alpha-2-claude:1\nterm-alpha-3:1\nai-beta-7-claude:1\n'
  ;;
*list-panes*@ai_column*)
  # The panes holding alpha's agent column and its terminal's tabs, both in window 2.
  printf 'alpha\talpha-2\t\t2\n'
  printf 'alpha\t\talpha-3\t2\n'
  printf 'beta\t\t\t1\n'
  ;;
*list-panes*-a*)
  # $SANDBOX/on is this tmux having columns open, which is what the toggle turns on.
  [[ -e $SANDBOX/on ]] && printf '%%1\t1\n%%2\t\n%%3\t1\n'
  ;;
*list-panes*)
  # A window's panes: its column first, if open, and a second one if a race left two.
  [[ -e $SANDBOX/on ]] && printf '%%5\t1\n'
  [[ -e $SANDBOX/twice ]] && printf '%%6\t1\n'
  printf '%%7\t\n'
  ;;
*list-clients*) echo "1790000000 /dev/pts/9" ;;
*split-window*) echo "%9" ;;
esac
echo "$args" >>"$SANDBOX/did"
STUB

# The agents' own records: one in alpha's column in a task's worktree, one waiting in beta,
# one stuck in delta, one finished and read in epsilon, and one on another tmux server.
cat >"$sandbox/path/desktop-agent-sessions" <<'STUB'
#!/usr/bin/env bash
cat <<'JSON'
{"sessions": [
  {"state": "waiting", "for": "5m", "socket": "/tmp/here", "target": "ai-alpha-2-claude:1.1",
   "pane": "%7", "cwd": "/w/alpha.worktrees/fix-runner", "agent": "claude",
   "asked": "make the runner retry"},
  {"state": "waiting", "for": "3m", "socket": "/tmp/here", "target": "beta:1.2", "agent": "claude",
   "pane": "%6", "cwd": "/w/beta", "pid": 4242},
  {"state": "working", "stuck": true, "quiet": "7m", "for": "40m", "socket": "/tmp/here",
   "target": "delta:1.2", "pane": "%8", "cwd": "/w/delta"},
  {"state": "done", "unseen": false, "for": "1h", "socket": "/tmp/here",
   "target": "epsilon:1.2", "pane": "%9", "cwd": "/w/epsilon"},
  {"state": "waiting", "for": "9m", "socket": "/tmp/elsewhere", "target": "gamma:1.2",
   "pane": "%1", "cwd": "/w/gamma"}
]}
JSON
STUB
# An agent is gone to through desktop-agent-tabs, which knows its column.
cat >"$sandbox/path/desktop-agent-tabs" <<'STUB'
#!/usr/bin/env bash
echo "$*" >>"$SANDBOX/did"
STUB
chmod +x "$sandbox/path/tmux" "$sandbox/path/desktop-agent-sessions" "$sandbox/path/desktop-agent-tabs"

# The script is loaded rather than run: its drawing and its tmux commands are what is
# being checked, and a curses screen needs a terminal no test has.
cat >"$sandbox/drive.py" <<'DRIVER'
import importlib.machinery, importlib.util, os, sys

loader = importlib.machinery.SourceFileLoader("sidebar", sys.argv[1])
spec = importlib.util.spec_from_loader("sidebar", loader)
sidebar = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sidebar)
# Colours belong to a screen that was never started; only the text is under test.
sidebar.curses.color_pair = lambda pair: 0
# Processes are read from a /proc of the test's own, never the machine's.
sidebar.PROC = os.environ["FAKE_PROC"]


class Branches:
    """desktop-branch-status, answering for the checkouts above."""
    @staticmethod
    def status(cwd, now):
        return {"/w/alpha.worktrees/fix-runner": {"branch": "fix-runner", "added": 42, "removed": 7,
                    "review": {"number": 12, "state": "opened", "checks": "failed",
                               "url": "https://host.example/r/-/merge_requests/12"}},
                "/w/gamma": {"branch": "main", "added": 1, "removed": 0}}.get(cwd, {})


def row(name, detailed=False):
    return next(r for r in sidebar.rows("alpha:2", detailed, Branches)
                if r["kind"] == "session" and r["session"] == name)


def agent(text):
    return next(r for r in sidebar.rows("alpha:2") if r["kind"] == "agent" and text in r["text"])


what = sys.argv[2]
if what in ("rows", "detail"):
    for found in sidebar.rows("alpha:2", what == "detail", Branches if what == "detail" else None):
        print(sidebar.line_of(found, 30)[0].rstrip())
elif what == "select-beta":
    for found in sidebar.rows("alpha:2", False, None, "beta"):
        print(sidebar.line_of(found, 30)[0].rstrip())
elif what == "step-agents":
    # Down from the last session: over the divider, onto the first agent.
    listed = sidebar.rows("alpha:2")
    last = max(i for i, r in enumerate(listed) if r["kind"] == "session")
    print(listed[sidebar.step(listed, last, 1)]["kind"])
elif what == "colours":
    print(" ".join(str(sidebar.xterm(c)) for c in ("#ff9e64", "#7aa2f7", "#000000", "#808080", "red")))
    print(" ".join(f"{r['text']}={r['model']}" for r in sidebar.rows("alpha:2") if r["kind"] == "agent"))
    print(" ".join(f"{m}={c}" for m, c in sorted(sidebar.agent_colours().items())))
elif what == "go-agent":
    sidebar.go(agent("claude 1"), "alpha:2")
elif what == "peek-agent":
    sidebar.peek(agent("claude 1"), "alpha:2")
elif what == "step":
    listed = sidebar.rows("alpha:2", True, Branches)
    alpha = next(i for i, r in enumerate(listed) if r["kind"] == "session")
    print(listed[sidebar.step(listed, alpha, 1)]["session"], listed[sidebar.step(listed, alpha, -1)]["session"])
elif what == "branches":
    for found in sidebar.rows("alpha:2", False, Branches):
        print(sidebar.line_of(found, 30)[0].rstrip())
elif what == "long-branch":
    found = {"kind": "sub", "parts": [("feat/a-branch-name-far-too-long", "dim"),
                                      ("+2191", "green"), ("−0", "red")]}
    print(sidebar.line_of(found, 30)[0].rstrip())
elif what == "owner":
    listed = sidebar.rows("alpha:2")
    second = next(i for i, r in enumerate(listed) if r["kind"] == "sub" and r["session"] == "alpha"
                  and any("fix-runner" in t for t, _ in r["parts"]))
    found = listed[sidebar.owner_of(listed, second)]
    print(found["kind"], found["text"])
elif what == "go":
    sidebar.go(row("beta"), "alpha:2")
elif what == "peek":
    sidebar.peek(row("beta"), "alpha:2")
elif what == "peek-alpha":
    sidebar.peek(row("alpha"), "alpha:2")
elif what == "peek-none":
    sidebar.peek(row("gamma"), "alpha:2")
elif what in ("tall", "short", "short-in-gamma", "short-detailed"):
    # The sessions with a branch under them, given a tall column and then a short one.
    room = 100 if what == "tall" else 8
    here = "gamma:1" if what == "short-in-gamma" else "alpha:2"
    listed = sidebar.rows(here, what == "short-detailed", Branches, None, room)
    spaces = listed[:next(i for i, r in enumerate(listed) if r["kind"] == "gap")]
    print(" ".join(r["session"] for r in spaces if r["kind"] == "sub"))
elif what == "long-name":
    found = {"kind": "agent", "text": "claude 1", "state": "waiting", "for": "5m",
             "model": "claude", "name": "opentofu-monorepo-b1"}
    print(sidebar.line_of(found, 34)[0].rstrip())
elif what == "names":
    for found in sidebar.rows("alpha:2"):
        if found["kind"] == "agent" and found["session"] == "alpha":
            print(sidebar.line_of(found, 40)[0].rstrip())
elif what == "cluster-colours":
    print(sidebar.cluster_part("lab")[1], sidebar.cluster_part("edge")[1])
elif what == "attach":
    sidebar.attach("alpha:2")
elif what == "toggle":
    sidebar.toggle()
elif what == "on":
    sidebar.on()
DRIVER

drive() {
  env -i PATH="$sandbox/path:/usr/bin:/bin" HOME=/home/u SANDBOX="$sandbox" TERM=dumb \
    CLAUDE_CONFIG_DIR="$sandbox/claude" FAKE_PROC="$sandbox/proc" XDG_STATE_HOME="$sandbox/state" \
    DESKTOP_CLUSTERS="$sandbox/clusters.conf" python3 "$sandbox/drive.py" "$ROOT/bin/desktop-tmux-sidebar" "$1" 2>&1
}

# Claude Code's records of its running sessions, with the name each answers to: one in
# alpha's third tab, alive -- this test's own shell stands in for it. One in the first whose
# process has gone, and one in the second whose pid has since been given to another
# process, started at another time.
mkdir -p "$sandbox/claude/sessions"
started=$(awk '{ sub(/.*\) /, ""); print $20 }' "/proc/$$/stat")
record() {
  printf '{"pid": %s, "procStart": "%s", "tmux": "%s", "name": "%s"}\n' "$1" "$2" "$3" "$4" \
    >"$sandbox/claude/sessions/$5.json"
}
record $$ "$started" 'ai-alpha-2-claude:@23.%33' alpha-c3 live
record 999999999 1 'ai-alpha-2-claude:@21.%31' gone-c1 gone
record $$ "$((started + 1))" 'ai-alpha-2-claude:@22.%32' reused-c2 reused

# --- what it draws -------------------------------------------------------------------------

drawn=$(drive rows)

sessions_drawn=$(sed -n '/^ SPACES/,/^$/p' <<<"$drawn" | sed '1d;$d')
check "the spaces come under a header that counts them" grep -q '^ SPACES  *5$' <<<"$drawn"

check "in a tall column a session has its branch under it" test "$(drive tall)" = gamma
check "in one the sessions would fill they lose it, so the agents fit underneath" \
  test -z "$(drive short)"
check "all but the one you are in" test "$(drive short-in-gamma)" = gamma
check "and v, which asks for more, gives them back" grep -qx gamma <<<"$(drive short-detailed)"

named=$(drive names)
check "a Claude agent keeps its model and tab, and after them the name it is messaged by" \
  grep -qE '^ ● claude 3 alpha-c3( |$)' <<<"$named"
check "not one whose process has gone" grep -qE '^ ● claude 1 +5m$' <<<"$named"
check "nor one whose pid now belongs to another process" grep -qx ' . claude 2' <<<"$named"
check "a name too long for the row is cut short, not the time on the right" \
  test "$(drive long-name)" = " ● claude 1 opentofu-monor…-b1 5m"
check "in the middle, since agents in one repository differ only at the end" \
  grep -q '…-b1 ' <<<"$(drive long-name)"
check "a row per session, and nothing else above the agents" \
  test "$(grep -v '^   ' <<<"$sessions_drawn" | sed 's/^.[●○·] \([^ ]*\).*/\1/' | paste -sd' ')" = "alpha beta delta epsilon gamma"
check "no windows are listed" lacks 'fish\|ide\|claude' <<<"$sessions_drawn"
check "an agent column's tabs are not a session of their own" lacks 'ai-\|term-' <<<"$drawn"
check "the session you are in is marked, on the left as herdr's active row" grep -q '^▌● alpha' <<<"$drawn"
check "a session shows its column's agents: two waiting, the first for 5m" \
  grep -q '^▌● alpha  *2 5m$' <<<"$drawn"
check "an agent waiting in a plain pane shows on its session" grep -q '^ ● beta  *3m$' <<<"$drawn"
check "an agent working and silent for minutes shows how long" grep -q '^ ● delta  *7m$' <<<"$drawn"
check "a session whose agents want nothing has a quiet dot" grep -q '^ ○ epsilon$' <<<"$drawn"
check "an agent on another tmux server is left out, and a session with none has a bare dot" \
  grep -q '^ · gamma$' <<<"$drawn"

drawn=$(drive branches)
check "under a session, the branch of its directory and what it changed, as its second line" \
  test "$(grep -A1 '^ · gamma$' <<<"$drawn" | tail -1)" = "   main +1 −0"

check "a long branch gives way to its counts, rather than cutting one in half" \
  test "$(drive long-branch)" = "   feat/a-branch-na… +2191 −0"

drawn=$(drive detail)
check "detailed, a session is followed by its task's checkout, named, and its review" \
  grep -q '^     fix-runner +42 −7 !12 ✗$' <<<"$drawn"
check "detailed, an agent is followed by what it was last asked" \
  grep -q '^     make the runner retry$' <<<"$drawn"
check "moving from a session steps over the lines under it, and never onto the header" \
  test "$(drive step)" = "beta alpha"

# --- the agents underneath -------------------------------------------------------------------

drawn=$(drive rows)
agents_drawn=$(sed -n '/^ AGENTS/,$p' <<<"$drawn")
check "under the spaces, a header names the session whose agents follow" \
  grep -q '^ AGENTS  *alpha$' <<<"$agents_drawn"
check "which is the session you are in, until the cursor picks another" \
  test "$(grep -c '^ AGENTS' <<<"$drawn")" = 1
check "each agent of a column is a row, by its model and tab, with how long" \
  grep -q '^ ● claude 1  *5m$' <<<"$agents_drawn"
check "and under it, its state in herdr's word and its task" \
  test "$(grep -A1 '^ ● claude 1 ' <<<"$agents_drawn" | tail -1)" = "   blocked · fix-runner"
check "a finished turn not yet read is done" \
  test "$(grep -A1 '^ ● claude 2$' <<<"$agents_drawn" | tail -1)" = "   done"
check "an opencode tab, which reports nothing, is listed idle" \
  test "$(grep -A1 '^ ○ opencode 1$' <<<"$agents_drawn" | tail -1)" = "   idle"
check "they come in tab order, claude before opencode" \
  test "$(grep -o 'claude [0-9]\|opencode [0-9]' <<<"$agents_drawn" | paste -sd,)" = "claude 1,claude 2,claude 3,opencode 1"
check "a terminal's tabs and plain windows with no agent are not agents" \
  lacks 'fish\|terminal' <<<"$agents_drawn"
check "a click on an agent's second line is a click on the agent" \
  test "$(drive owner)" = "agent claude 1"

drawn=$(drive select-beta)
check "with the cursor on another session, its agents are the ones shown" \
  grep -q '^ AGENTS  *beta$' <<<"$drawn"
check "an agent in a plain pane is named after its window" \
  grep -q '^ ● claude · ide *3m$' <<<"$drawn"

check "moving down from the last session skips the header and lands on an agent" \
  test "$(drive step-agents)" = agent

: >"$sandbox/did"
drive go-agent >/dev/null
check "a click on an agent goes to that agent, through its column, moving this client" \
  grep -q 'jump %7 /dev/pts/9' "$sandbox/did"

: >"$sandbox/did"
drive peek-agent >/dev/null
check "peek on an agent shows that agent" grep -q "desktop-agent-peek '%7'" "$sandbox/did"

colours=$(drive colours)
check "a theme's hex colour is drawn as the nearest of the 256: claude's orange, opencode's blue" \
  test "$(sed -n 1p <<<"$colours")" = "215 111 16 244 None"
check "each agent row knows its model, for its colour" \
  grep -q 'claude 1=claude .*opencode 1=opencode' <<<"$(sed -n 2p <<<"$colours")"
check "the colours are the theme's, as tmux has them" \
  test "$(sed -n 3p <<<"$colours")" = "claude=#ff9e64 codex=#a9b1d6 opencode=#7aa2f7"

# --- what it does --------------------------------------------------------------------------

: >"$sandbox/did"
drive go >/dev/null
check "a click switches the client looking at the sidebar, by name, to the session" \
  grep -q 'switch-client -c /dev/pts/9 -t =beta' "$sandbox/did"

: >"$sandbox/did"
drive peek >/dev/null
check "peek opens a popup on the client looking at the sidebar" \
  grep -q 'display-popup -c /dev/pts/9 -E' "$sandbox/did"
check "showing the pane of the session's agent" grep -q "desktop-agent-peek '%6' '/dev/pts/9'" "$sandbox/did"

: >"$sandbox/did"
drive peek-alpha >/dev/null
check "in a session with several, the agent most in need of you" \
  grep -q "desktop-agent-peek '%7'" "$sandbox/did"

: >"$sandbox/did"
drive peek-none >/dev/null
check "a session with no agent says so rather than opening an empty popup" \
  grep -q 'No agent in gamma' "$sandbox/did"
check "and opens none" lacks 'display-popup' "$sandbox/did"

: >"$sandbox/did"
drive toggle >/dev/null
check "a column is opened in every window on screen, once" \
  test "$(grep -c 'split-window' "$sandbox/did")" = 2
check "and not yet in one nobody is looking at: it gets its own when it is looked at" \
  lacks 'split-window -t alpha:2' "$sandbox/did"
check "the tabs inside an agent column or terminal pane get none of their own" \
  lacks 'split-window -t ai-\|split-window -t term-' "$sandbox/did"
check "nor one whose tabs have not marked it yet, as the new-session hook finds it" \
  lacks 'split-window -t ai-beta-7' "$sandbox/did"
check "it spans the window and leaves the cursor where it was" \
  grep -q 'split-window -t alpha:1 -fhbd -l 30' "$sandbox/did"
check "and the shell it starts in becomes the sidebar, rather than idling behind it" \
  grep -q "split-window -t alpha:1 -fhbd -l 30 -P -F #{pane_id} exec '\\?/" "$sandbox/did"
check "and each window it opens one in is marked" grep -q 'set-option -wq -t alpha:1 @sidebar_held 1' "$sandbox/did"
check "new windows get one too" grep -q 'set-hook -g after-new-window\[50\] ' "$sandbox/did"
check "in a slot of its own, so the tabs' hooks on the same event survive" \
  lacks 'set-hook -g after-new-window ' "$sandbox/did"
check "a new session's names the session, since it has no window to name" \
  grep -q 'set-hook -g after-new-session\[50\] .*#{?hook_window,#{hook_window},#{session_name}:^}' "$sandbox/did"

touch "$sandbox/on"
: >"$sandbox/did"
drive on >/dev/null
check "--on, as a tmux.conf reload runs it, leaves open columns open" \
  lacks 'kill-pane' "$sandbox/did"
check "and still hooks new windows" grep -q 'set-hook -g after-new-window\[50\] ' "$sandbox/did"
check "and a window that missed its column gets one when it is looked at" \
  grep -q "set-hook -g session-window-changed\[50\] if -F '#{@sidebar_held}' '' " "$sandbox/did"
check "on every way of coming to look at one" \
  test "$(grep -c "set-hook -g \(client-session-changed\|session-window-changed\|client-attached\)\[50\] if -F" "$sandbox/did")" = 3
check "tmux.conf turns it on as the server starts" \
  grep -q '^run-shell "desktop-tmux-sidebar --on"' "$ROOT/config/tmux/tmux.conf"

: >"$sandbox/did"
drive attach >/dev/null
check "a window that has a column is not given a second" lacks 'split-window' "$sandbox/did"
check "and is marked as having one, so looking at it again asks nothing" \
  grep -q 'set-option -wq -t alpha:2 @sidebar_held 1' "$sandbox/did"

touch "$sandbox/twice"
: >"$sandbox/did"
drive attach >/dev/null
check "a window that ended up with two columns keeps the first" lacks 'kill-pane -t %5' "$sandbox/did"
check "and loses the second" grep -q 'kill-pane -t %6' "$sandbox/did"
check "and gains none" lacks 'split-window' "$sandbox/did"
rm "$sandbox/twice"

: >"$sandbox/did"
drive toggle >/dev/null
check "turning it off closes every column" \
  test "$(grep -c 'kill-pane' "$sandbox/did")" = 2
check "and removes only its own hook" grep -q 'set-hook -gu after-new-window\[50\]' "$sandbox/did"
check "the looking-at ones as well" grep -q 'set-hook -gu session-window-changed\[50\]' "$sandbox/did"
check "and forgets which windows had one" grep -q 'set-option -wqu -t .* @sidebar_held' "$sandbox/did"

# A column off screen stays quiet until tmux says what is on screen changed: tmux.conf
# touches the mark the sidebar watches, by the same name.
mark=$(sed -n 's/.*"\(desktop-tmux-view\)").*/\1/p' "$ROOT/bin/desktop-tmux-sidebar" | head -1)
check "tmux.conf touches the mark the sidebar watches" \
  test "$mark" = desktop-tmux-view -a "$(grep -c "touch .*/$mark" "$ROOT/config/tmux/tmux.conf")" = 5

# tmux.conf, read by a real tmux. A line tmux refuses -- "${X:-y}" in a hook is one, as
# its parser expands ${} itself and knows no default -- fails only that line, quietly, on
# a server already running: the hooks it was to set are simply not there.
# The real tmux, on a server of its own, with no desktop-* commands on PATH: the
# run-shell lines in the file then do nothing.
real=$(PATH=/usr/bin:/bin command -v tmux)
if [[ -n $real ]]; then
  socket="desktop-test-$$"
  errors=$(env -u TMUX PATH=/usr/bin:/bin "$real" -L "$socket" -f /dev/null new-session -d \; \
    source-file "$ROOT/config/tmux/tmux.conf" 2>&1 >/dev/null)
  "$real" -L "$socket" kill-server 2>/dev/null
  rm -f "/tmp/tmux-$(id -u)/$socket"
  check "tmux reads tmux.conf without an error" test -z "$errors"
  [[ -n $errors ]] && echo "      $(head -3 <<<"$errors")"
fi

# --- clusters
# A process as /proc has it: its start time in stat, its environment NUL-separated.
process() { # pid ppid environment...
  mkdir -p "$sandbox/proc/$1/task/$1"
  echo "$1 (x) S $2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 77 0" >"$sandbox/proc/$1/stat"
  shift 2
  printf '%s\0' PATH=/usr/bin "$@" >"$sandbox/proc/${pid}/environ"
}
pid=4242 process 4242 1 DESKTOP_CLUSTER=lab KUBECONFIG=/home/u/.local/state/desktop/clusters/lab.kubeconfig
# The opencode tab: a wrapper with no cluster, and under it opencode, started from an
# ocl -e shell, with only a KUBECONFIG of ocl's to say which.
pid=5002 process 5002 1
pid=5003 process 5003 5002 "KUBECONFIG=$sandbox/state/desktop/clusters/edge.kubeconfig"
echo 5003 >"$sandbox/proc/5002/task/5002/children"
pid=5001 process 5001 1 DESKTOP_CLUSTER=lab
printf 'lab   rke2  ssh=admin@lab.example prod=true\nedge  talos talosconfig=/t\n' >"$sandbox/clusters.conf"
touch "$sandbox/with-clusters"
clustered=$(drive rows)
# second_line <session>: the line drawn under a session's row.
second_line() { grep -A1 -x " · $1" <<<"$clustered" | sed -n 2p; }
check "a cluster's own session has the cluster as its second line" \
  test "$(second_line k8s-lab)" = '   ⎈ lab'
check "an agent says which cluster it can reach, after its state" \
  grep -qx '   blocked ⎈ lab' <<<"$(drive select-beta)"
check "found under the pane when its own process is not the one on it" \
  grep -qx '   idle ⎈ edge' <<<"$clustered"
check "and from a kubeconfig of ocl's when nothing else says" \
  test "$(grep -c '⎈ edge' <<<"$clustered")" = 1
check "a view's session says so, with its cluster after it" \
  test "$(second_line view-upgrade)" = '   ◆ view ⎈ lab'
check "a production cluster is red, any other blue" test "$(drive cluster-colours)" = "red blue"
rm -rf "$sandbox/with-clusters" "$sandbox/proc"
check "an agent on no cluster says nothing of one" lacks '⎈' <<<"$(drive rows)"

finish
