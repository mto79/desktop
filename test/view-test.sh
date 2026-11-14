#!/usr/bin/env bash
# Views (desktop-view) and the one list of every place to work (desktop-pick).
#
# Against a real tmux server on a socket of its own: a view is built, gone to, saved again
# from what is open, and listed; a file written wrong is refused with what is wrong in it.
# The agent is a stub named claude that echoes what it is given, so a prompt typed in shows
# once and a prompt sent would show twice. Nothing here may start a real claude.
source "$(dirname "$0")/lib.sh"

require tmux || finish
require python3 || finish

TMUX_BIN=$(command -v tmux)
SOCKET="desktop-view-test-$$"
sandbox=$(mktemp -d)
holder="" attached=""
trap '"$TMUX_BIN" -L "$SOCKET" kill-server 2>/dev/null; kill $attached $holder 2>/dev/null; rm -rf "$sandbox"' EXIT

stubs="$sandbox/bin"
mkdir -p "$stubs" "$sandbox/work" "$sandbox/config/desktop/views" "$sandbox/state/desktop/clusters" \
  "$sandbox/repos/gitops/.git" "$sandbox/repos/infra.worktrees/fix-x"
cat >"$stubs/tmux" <<STUB
#!/usr/bin/env bash
exec "$TMUX_BIN" -L "$SOCKET" "\$@"
STUB
cp /bin/cat "$stubs/claude"
printf '#!/usr/bin/env bash\nexec claude\n' >"$stubs/desktop-agent"
printf '#!/usr/bin/env bash\nexit 0\n' >"$stubs/kubectl"
printf '#!/usr/bin/env bash\necho "k9s on $DESKTOP_CLUSTER"; exec sleep 300\n' >"$stubs/k9s"
chmod +x "$stubs"/*

export HOME="$sandbox" XDG_CONFIG_HOME="$sandbox/config" XDG_STATE_HOME="$sandbox/state"
export PATH="$stubs:$ROOT/bin:$PATH" EDITOR=true SHELL=/bin/bash
export TMUX_SESSIONIZER_CONFIG_FILE="$sandbox/sessionizer"
unset TMUX DESKTOP_VIEW_CLIENT DESKTOP_VIEW_SESSION
echo "$sandbox/repos" >"$sandbox/sessionizer"
echo 'lab rke2 kubeconfig=/dev/null' >"$sandbox/config/desktop/clusters.conf"
echo fake >"$sandbox/state/desktop/clusters/lab.kubeconfig"
views="$sandbox/config/desktop/views"

tm() { "$TMUX_BIN" -L "$SOCKET" "$@"; }
settle() {

  for _ in $(seq 80); do
    eval "$1" >/dev/null 2>&1 && return 0
    sleep 0.1
  done
  return 1
}
view() { desktop-view "$@" 2>&1; }

cat >"$views/upgrade.toml" <<TOML
description = "GitLab upgrade on lab"
dir = "~/work"
cluster = "lab"

[[window]]
name = "ide"
kind = "agent"
prompt = "Read UPGRADE.md"

[[window]]
name = "k9s"
kind = "k9s"

[[window]]
name = "watch"
layout = "even-horizontal"
panes = ["echo first-pane", { dir = "~/repos", command = "echo second-pane" }]
TOML

tm new-session -d -s home -x 200 -y 50 -c "$sandbox/repos/gitops"

# --- what it would build, and what it builds -----------------------------------------------
shown=$(view show upgrade)
check "show says what open would build" grep -q 'view-upgrade  in ~/work  on ⎈ lab' <<<"$shown"
check "an agent window, with its prompt" grep -qE '^  ide +agent column: claude x1 · prompt typed in' <<<"$shown"
check "a cluster window" grep -qE '^  k9s +k9s on lab' <<<"$shown"

view open upgrade --detached >/dev/null
settle "tm has-session -t =view-upgrade"
check "open builds the session, view- and its name" tm has-session -t =view-upgrade
check "marked as a view, and with its cluster, for the sidebar and the restore" \
  test "$(tm display-message -p -t =view-upgrade: '#{@view} #{@cluster}')" = "upgrade lab"
check "its windows in the file's order, and nothing else" \
  test "$(tm list-windows -t =view-upgrade: -F '#W' | paste -sd' ')" = "ide k9s watch"
check "the cluster is in the session's environment, for every window" \
  test "$(tm show-environment -t =view-upgrade DESKTOP_CLUSTER)" = DESKTOP_CLUSTER=lab
column=$(tm list-sessions -F '#S' | grep '^ai-' | head -1)
check "the agent's column is laid out, as desktop-agent-layout makes one" test -n "$column"
check "and is on the view's cluster too" test "$(tm show-environment -t "=$column" DESKTOP_CLUSTER 2>/dev/null)" = DESKTOP_CLUSTER=lab
check "k9s runs on the cluster" settle "tm capture-pane -p -t =view-upgrade:k9s | grep -q 'k9s on lab'"
check "a pane's command is typed into its shell and run" \
  settle "tm capture-pane -p -t =view-upgrade:watch.0 | grep -qx first-pane"
check "in the pane's own directory when it has one" \
  test "$(tm display-message -p -t =view-upgrade:watch.1 '#{pane_current_path}')" = "$sandbox/repos"
pane=$(tm list-panes -t "=$column:" -F '#{pane_id}' | head -1)
check "the prompt is typed into the agent once it is up" \
  settle "tm capture-pane -p -t '$pane' | grep -q 'Read UPGRADE.md'"
sleep 0.5
check "and not sent: an echo would show it twice" test "$(tm capture-pane -p -t "$pane" | grep -c 'Read UPGRADE.md')" = 1

view open upgrade --detached >/dev/null
check "opened again it is gone to, not built twice" test "$(tm list-windows -t =view-upgrade: | wc -l)" = 3

# --- written down from what is open --------------------------------------------------------
tm send-keys -t =view-upgrade:watch.1 -l 'sleep 300' && tm send-keys -t =view-upgrade:watch.1 Enter
settle "test \"\$(tm display-message -p -t =view-upgrade:watch.1 '#{pane_current_command}')\" = sleep"
DESKTOP_VIEW_SESSION=view-upgrade view save copy >/dev/null
saved="$views/copy.toml"
check "save writes the session as a view" test -s "$saved"
check "with its directory and its cluster" bash -c "grep -qx 'dir = \"~/work\"' '$saved' && grep -qx 'cluster = \"lab\"' '$saved'"
check "an agent window as an agent window" grep -qx 'kind = "agent"' "$saved"
check "k9s as k9s, not as the shell it runs in" grep -qx 'kind = "k9s"' "$saved"
check "a pane by the command running in it now" grep -q 'command = "sleep 300"' "$saved"
check "and it opens as it was saved" bash -c "desktop-view show copy | grep -qE '^  watch +2 pane'"
check "save does not write over a view" bash -c "! DESKTOP_VIEW_SESSION=view-upgrade desktop-view save copy 2>/dev/null"

# --- a file written wrong ------------------------------------------------------------------
printf 'dir = "~/nowhere"\n[[window]]\nkind = "k9s"\n[[window]]\nname = "x"\nkind = "tv"\n' >"$views/broken.toml"
said=$(view show broken)
check "a view written wrong is refused, every mistake said" \
  bash -c "grep -q 'nowhere is not a directory' <<<'$said' && grep -q 'k9s needs cluster' <<<'$said' && grep -q 'not tv' <<<'$said'"
printf 'dir = [\n' >"$views/torn.toml"
check "and one that is not TOML says where" bash -c "desktop-view show torn 2>&1 | grep -q 'torn.toml: '"
check "a name that could be a path is not a view name" bash -c "desktop-view show ../x 2>&1 | grep -q 'not a view name'"
check "a view not there says which there are" bash -c "desktop-view show nope 2>&1 | grep -q 'there are: '"
rm "$views/broken.toml" "$views/torn.toml"

# --- the list ------------------------------------------------------------------------------
check "list says which are open, and their cluster" grep -qP '^upgrade\topen\t⎈ lab\tGitLab upgrade on lab$' <<<"$(view list)"
view edit fresh >/dev/null
check "edit starts a new view from an example that opens" bash -c "desktop-view show fresh >/dev/null"
view rm fresh >/dev/null
check "rm removes the file" test ! -e "$views/fresh.toml"

# --- every place to work, in one list ------------------------------------------------------
client_list=$(desktop-pick --list)
check "an open view is listed as open, with its description" grep -qE '◆  view-upgrade +view +open +GitLab upgrade on lab' <<<"$client_list"
check "a view not open is listed to open" grep -qE '◆  copy +view +on lab' <<<"$client_list"
check "a cluster not open, by its kind" grep -qE '⎈  lab +cluster +rke2' <<<"$client_list"
check "a repository not open, from the sessionizer's roots" grep -qE '^ +gitops +repo +~/repos/gitops' <<<"$client_list"
check "a task beside its repository" grep -qE 'infra · fix-x +task' <<<"$client_list"
check "an agent column's session is no place of its own" lacks 'ai-' <<<"$client_list"
order=$(awk '{ for (i = 1; i <= NF; i++) if ($i ~ /^(repo|view|cluster|task|session)$/) { print ($(i+1) == "open" ? "open" : "closed"); break } }' <<<"$client_list" | uniq | paste -sd' ')
check "open before closed" test "$order" = "open closed"

# Chosen in the popup, with a real client attached: fzf is a stub that picks $sandbox/want.
if command -v script >/dev/null 2>&1; then
  cat >"$stubs/fzf" <<STUB
#!/usr/bin/env bash
cat >"$sandbox/shown"
echo
grep -F "\$(cat "$sandbox/want")" "$sandbox/shown" | head -1
STUB
  chmod +x "$stubs/fzf"
  # A client needs a terminal tmux can draw on, which a test may run without, and input
  # held open: script reads its stdin, and at the end of it the client leaves. A named pipe
  # with a sleep at the other end, both killed when the test ends.
  mkfifo "$sandbox/hold"
  sleep 300 >"$sandbox/hold" 2>/dev/null &
  holder=$!
  TERM=xterm-256color script -qfc "$TMUX_BIN -L $SOCKET attach -t home" /dev/null <"$sandbox/hold" >/dev/null 2>&1 &
  attached=$!
  settle "tm list-clients -F '#{client_session}' | grep -qx home"
  client=$(tm list-clients -F '#{client_name} #{client_session}' | awk '$2 == "home" { print $1; exit }')
  on() { tm list-clients -F '#{client_name} #{client_session}' | awk -v c="$client" '$1 == c { print $2 }'; }
  echo "view:copy" >"$sandbox/want"
  DESKTOP_PICK_POPUP=1 desktop-pick --client "$client" >/dev/null 2>&1
  check "Enter on a view not open builds it and moves the client there" settle '[[ $(on) == view-copy ]]'
  echo "session:home" >"$sandbox/want"
  DESKTOP_PICK_POPUP=1 desktop-pick --client "$client" >/dev/null 2>&1
  check "Enter on an open session switches to it" settle '[[ $(on) == home ]]'
  echo "cluster:lab" >"$sandbox/want"
  DESKTOP_PICK_POPUP=1 desktop-pick --client "$client" >/dev/null 2>&1
  check "Enter on a cluster opens its session" settle '[[ $(on) == k8s-lab ]]'
  echo "repo:$sandbox/repos/gitops" >"$sandbox/want"
  DESKTOP_PICK_POPUP=1 desktop-pick --client "$client" >/dev/null 2>&1
  check "Enter on a repository makes its session" settle '[[ $(on) == gitops ]]'
  kill "$attached" "$holder" 2>/dev/null
fi
check "prefix + s opens it" grep -q "bind-key s run-shell -b \"desktop-pick --client '#{client_name}'\"" "$ROOT/config/tmux/tmux.conf"

# --- after a reboot ------------------------------------------------------------------------
desktop-tmux-restore save >/dev/null 2>&1
check "the restore writes a view's session down as the view" \
  test "$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print([s.get("view") for s in d["sessions"] if s["name"]=="view-upgrade"][0])' "$sandbox/state/desktop/tmux/last.json")" = upgrade
tm kill-server
# Gone, not going: a restore that asks a server still on its way out is told nothing, which
# is a race no reboot has.
settle "! tm list-sessions"
desktop-tmux-restore restore >/dev/null 2>&1
settle "tm has-session -t =view-upgrade"
check "and builds it again from its file, cluster and all" \
  test "$(tm display-message -p -t =view-upgrade: '#{@view} #{@cluster}')" = "upgrade lab"
check "without doubling a window" test "$(tm list-windows -t =view-upgrade: -F '#W' | paste -sd' ')" = "ide k9s watch"

finish
