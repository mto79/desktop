#!/usr/bin/env bash

# The sidebar's / filter, and sessions made, renamed and closed from it (n, R, x): the rows
# a filter keeps, and the sessions the keys make and close on a tmux server of the test's
# own -- never the one running it.

source "$(dirname "$0")/lib.sh"

sandbox=$(mktemp -d)
real=$(PATH=/usr/bin:/bin command -v tmux)
rt() { env -u TMUX TMUX_TMPDIR="$sandbox/tmux" "$real" "$@"; }
trap 'rt kill-server 2>/dev/null; rm -rf "$sandbox"' EXIT
mkdir -p "$sandbox/tmux" "$sandbox/bin" "$sandbox/repos/gitops/.git" "$sandbox/home"
echo "$sandbox/repos" >"$sandbox/sessionizer"

# A repository's session is desktop-repo-session's to make; here it makes a plain one.
cat >"$sandbox/bin/desktop-repo-session" <<STUB
#!/usr/bin/env bash
name=\$(basename "\$1")
env -u TMUX TMUX_TMPDIR="$sandbox/tmux" "$real" new-session -d -s "\$name" -c "\$1"
echo "repo \$1" >>"$sandbox/did"
echo "\$name"
STUB
cat >"$sandbox/bin/tmux" <<STUB
#!/usr/bin/env bash
exec env -u TMUX TMUX_TMPDIR="$sandbox/tmux" "$real" "\$@"
STUB
chmod +x "$sandbox/bin/"*

cat >"$sandbox/drive.py" <<'DRIVER'
import importlib.machinery, importlib.util, sys

loader = importlib.machinery.SourceFileLoader("sidebar", sys.argv[1])
spec = importlib.util.spec_from_loader("sidebar", loader)
sidebar = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sidebar)

def r(kind, name, section="repos", **more):
    return dict(kind=kind, text=name, session=name, section=section, current=False, **more)

listed = [r("section", "REPOS"), r("session", "awx"), r("sub", "awx"), r("session", "ocp-helm-charts"),
          r("section", "CLUSTERS", "clusters"), r("cluster", "ocp202", "clusters"), r("cluster", "ocp303", "clusters"),
          r("gap", ""), r("section", "AGENTS", "agents"), r("agent", "claude 1", "agents", pane="%1")]

what = sys.argv[2]
if what == "match":
    print(" ".join(f"{x['kind']}:{x['text']}" for x in sidebar.matching(listed, sys.argv[3])))
elif what == "first":
    print(sidebar.first_choice(sidebar.matching(listed, sys.argv[3])))
elif what == "new":
    sidebar.new_session(sys.argv[3], "")
elif what == "close":
    sidebar.close_session(sys.argv[3])
DRIVER
drive() { HOME="$sandbox/home" TMUX_SESSIONIZER_CONFIG_FILE="$sandbox/sessionizer" PATH="$sandbox/bin:$PATH" \
  python3 "$sandbox/drive.py" "$ROOT/bin/desktop-tmux-sidebar" "$@" 2>&1; }

check "a filter keeps what has the text in its name, under its section, with its second line" \
  test "$(drive match aw)" = "section:REPOS session:awx sub:awx"
check "  in any section, case or not" test "$(drive match OCP3)" = "section:CLUSTERS cluster:ocp303"
check "  agents too" test "$(drive match claude)" = "section:AGENTS agent:claude 1"
check "  and a section with nothing in it is not shown at all" lacks REPOS <<<"$(drive match ocp202)"
check "the cursor starts on the first thing to go to, not its header" test "$(drive first ocp)" = 1
check "nothing matching is an empty list" test -z "$(drive match zzz)"

rt new-session -d -s home
drive new scratch >/dev/null
check "n makes a session by name, a shell at home" \
  test "$(rt list-sessions -F '#{session_name} #{session_path}' | sed -n 's/^scratch //p')" = "$sandbox/home"
drive new gitops >/dev/null
check "  and a repository's, its own way, when one of that name is in the sessionizer's folders" \
  grep -qx "repo $sandbox/repos/gitops" "$sandbox/did"
drive new gitops >/dev/null
check "  one that exists is switched to, not made twice" test "$(grep -c '^repo' "$sandbox/did")" = 1
drive new a.b:c >/dev/null
check "  a name tmux would refuse is made one it takes" rt has-session -t =a_b_c

rt new-session -d -s ai-gitops-1
drive close scratch >/dev/null
check "x closes the session" bash -c "! env -u TMUX TMUX_TMPDIR='$sandbox/tmux' '$real' has-session -t =scratch 2>/dev/null"
check "  and leaves the rest" rt has-session -t =gitops
check "the session a client is sent to is never a column's helper" \
  bash -c "$(declare -f drive); sandbox='$sandbox' ROOT='$ROOT' python3 -c \"
import importlib.machinery, importlib.util, os, sys
os.environ['PATH'] = '$sandbox/bin:' + os.environ['PATH']
l = importlib.machinery.SourceFileLoader('s', '$ROOT/bin/desktop-tmux-sidebar')
s = importlib.util.spec_from_loader('s', l); m = importlib.util.module_from_spec(s); l.exec_module(m)
sys.exit(0 if not (m.elsewhere('gitops') or '').startswith(('ai-', 'term-')) else 1)\""

check "the footer names the new keys" grep -q 'FOOTER = "⏎ go  / find  n new' "$ROOT/bin/desktop-tmux-sidebar"

finish
