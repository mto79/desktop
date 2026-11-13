#!/usr/bin/env bash
# What tmux looked like, written down and built again.
#
# Against a real tmux server on a socket of its own, twice: one to build and save, and --
# after it has been killed, which is what a reboot is to tmux -- a second to restore into.
# What matters is that the second one ends up shaped like the first: the same sessions,
# the windows laid out for agents with their tabs and their tasks, and nothing doubled.
#
# The agents and lazygit are stubs. Nothing here may start a real claude.
source "$(dirname "$0")/lib.sh"

require tmux || finish
require python3 || finish

TMUX_BIN=$(command -v tmux)
SOCKET="desktop-restore-test-$$"
RESTORE="$ROOT/bin/desktop-tmux-restore"

sandbox=$(mktemp -d)
trap 'kill "${claude_pid:-}" 2>/dev/null; "$TMUX_BIN" -L "$SOCKET" kill-server 2>/dev/null; rm -f "${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/$SOCKET"; rm -rf "$sandbox"' EXIT

stubs="$sandbox/bin"
mkdir -p "$stubs" "$sandbox/work" "$sandbox/notes" "$sandbox/work.worktrees/fix-runner"

cat >"$stubs/tmux" <<STUB
#!/usr/bin/env bash
exec "$TMUX_BIN" -L "$SOCKET" "\$@"
STUB
printf '#!/usr/bin/env bash\nexec sleep 300\n' >"$stubs/desktop-agent"
printf '#!/usr/bin/env bash\nexec sleep 300\n' >"$stubs/lazygit"
chmod +x "$stubs"/*

# XDG_CONFIG_HOME as well as HOME: tmux looks there first, and would otherwise load the
# tmux.conf deployed on this machine, hooks and all.
export HOME="$sandbox" XDG_CONFIG_HOME="$sandbox/config" XDG_STATE_HOME="$sandbox/state"
export PATH="$stubs:$ROOT/bin:$PATH" EDITOR=true SHELL=/bin/bash XDG_RUNTIME_DIR="$sandbox/run"
tm() { "$TMUX_BIN" -L "$SOCKET" "$@"; }
settle() {
  local i
  for i in $(seq 60); do
    eval "$1" >/dev/null 2>&1 && return 0
    sleep 0.1
  done
  return 1
}
shape() { "$RESTORE" show | tail -n +2; }

# --- something worth restoring -------------------------------------------------------------

tm new-session -d -s work -n ide -c "$sandbox/work" -x 200 -y 50
desktop-agent-layout work:ide claude
editor=$(tm list-panes -t work:ide -F '#{pane_id}' | head -1)
group=$(tm list-panes -t work:ide -F '#{@ai_column}' | grep -m1 .)
settle "tm list-clients -F '#{client_session}' | grep -qx 'ai-$group-claude'"
desktop-agent-tabs new "$editor"                                             # a second claude
desktop-agent-tabs new "$editor" "" "$sandbox/work.worktrees/fix-runner"     # one on a task
desktop-agent-tabs model "$editor" codex                                     # and a codex
settle "tm list-clients -F '#{client_session}' | grep -qx 'ai-$group-codex'"
desktop-agent-tabs model "$editor" claude
settle "tm list-clients -F '#{client_session}' | grep -qx 'ai-$group-claude'"
shell=$(tm list-panes -t work:ide -F '#{pane_id} #{@term_pane}' | awk 'NF > 1 { print $1 }')
desktop-terminal-tabs new "$shell"                                           # a second terminal

tm new-window -d -t work: -n git -c "$sandbox/work" lazygit
tm new-session -d -s notes -n scratch -c "$sandbox/notes" -x 200 -y 50
tm split-window -d -t notes:scratch -c "$sandbox/notes"
# A window with the sidebar's column in it, which is the sidebar's to put back, not this.
tm new-window -d -t notes: -n side -c "$sandbox/notes"
tm split-window -d -fhb -l 30 -t notes:side "sleep 300"
tm set-option -p -t "$(tm list-panes -t notes:side -F '#{pane_id}' | head -1)" @sidebar 1

# Claude Code's record of each claude tab's conversation, as it writes one per session: a
# live process called claude, its session id and its pane. And a transcript for each, which
# is what makes a conversation one that can be resumed.
ln -s "$(command -v sleep)" "$sandbox/claude"
"$sandbox/claude" 300 >/dev/null 2>&1 &
claude_pid=$!
mkdir -p "$HOME/.claude/sessions"
ids=(11111111-1111-4111-8111-111111111111 22222222-2222-4222-8222-222222222222 33333333-3333-4333-8333-333333333333)
n=0
while read -r where pane dir; do
  printf '{"pid":%d,"sessionId":"%s","tmux":"%s.%s"}\n' "$claude_pid" "${ids[n]}" "$where" "$pane" \
    >"$HOME/.claude/sessions/$((1000 + n)).json"
  mkdir -p "$HOME/.claude/projects/${dir//[^A-Za-z0-9]/-}"
  touch "$HOME/.claude/projects/${dir//[^A-Za-z0-9]/-}/${ids[n]}.jsonl"
  n=$((n + 1))
done < <(tm list-windows -a -f "#{&&:#{==:#{@ai_group},$group},#{==:#{@ai_model},claude}}" \
  -F '#{window_index} #{session_name}:#{window_id} #{pane_id} #{pane_start_path}' | sort -n | cut -d' ' -f2-)
check "the three claude tabs were given a conversation each" test "$n" = 3

"$RESTORE" save
saved=$(python3 -c 'import json, sys
for s in json.load(open(sys.argv[1]))["sessions"]:
    for w in s["windows"]:
        for t in (w.get("tabs") or {}).get("claude", []):
            print(t.get("session", "-"))' "$sandbox/state/desktop/tmux/last.json" | tr '\n' ' ')
check "each claude tab's conversation is written down with it, in tab order" test "$saved" = "${ids[*]} "
before=$(shape)
side=$(python3 -c 'import json, sys
for s in json.load(open(sys.argv[1]))["sessions"]:
    for w in s["windows"]:
        if w["name"] == "side":
            print(len(w["panes"]), repr(w.get("layout")))' "$sandbox/state/desktop/tmux/last.json")
check "the sidebar's column is not saved as a pane of its window" test "${side%% *}" = 1
check "nor is a layout that counts it" test "${side#* }" = "''"
check "the picture has both sessions" test "$(grep -c '^[a-z]' <<<"$before")" = 2
check "the agent window is known for what it is, tabs and all" \
  grep -qE '^  ide +agent window  .*claude x3' <<<"$before"
check "with the other model's tabs" grep -qE '^  ide .*codex x1' <<<"$before"
check "the task one of them is on" grep -q 'tasks: fix-runner' <<<"$before"
check "and the second terminal" grep -q 'terminals x2' <<<"$before"
check "the sessions behind the column are not places of their own" lacks '^ai-\|^term-' <<<"$before"

# --- saving must not lose it ---------------------------------------------------------------

# A server on its way down answers nothing, or answers with nothing left. Neither may
# replace what was written while it was whole.
kept=$(cat "$sandbox/state/desktop/tmux/last.json")
tm kill-server
"$RESTORE" save
check "with no server to ask, what was saved stays" \
  test "$(cat "$sandbox/state/desktop/tmux/last.json")" = "$kept"

# --- and back again ------------------------------------------------------------------------

check "restore builds it" grep -q 'window(s) put back' <<<"$("$RESTORE" restore)"
settle "tm list-sessions -F '#{session_name}' | grep -q '^ai-work-.*-codex$'"
after=$(shape)
check "the same sessions and windows come back, shaped as they were" test "$after" = "$before"
resumed=$(tm list-windows -a -f "#{==:#{@ai_model},claude}" -F '#{window_index} #{pane_start_command}' | sort -n |
  grep -o -- '--resume [0-9a-f-]*' | cut -d' ' -f2 | tr '\n' ' ')
check "each claude tab resumes its own conversation, not the directory's latest" test "$resumed" = "${ids[*]} "
check "and nothing is left queued for a tab opened later" test -z "$(ls -A "$sandbox/run/desktop/agent-resume" 2>/dev/null | grep -v '\.lock$')"
check "the task's tab is in its worktree again" \
  test "$(tm list-windows -a -F '#{@worktree}' | grep -c "work.worktrees/fix-runner$")" = 1
check "the column is left on the model it was on" \
  test "$(tm list-panes -t work:ide -F '#{@ai_model}' | grep -m1 .)" = claude
check "the window that was lazygit is lazygit" \
  grep -q lazygit <<<"$(tm list-panes -t work:git -F '#{pane_start_command}')"
check "a plain window gets its panes back" test "$(tm list-panes -t notes:scratch | wc -l)" = 2
check "and no placeholder is left behind" lacks -x restoring <<<"$(tm list-windows -a -F '#{window_name}')"

"$RESTORE" restore >/dev/null
check "restoring twice doubles nothing" test "$(shape)" = "$before"

# The login script lays a session out before the restore runs; only what is missing is added.
tm kill-window -t work:git
"$RESTORE" save
tm kill-window -t notes:scratch 2>/dev/null
tm new-window -d -t work: -n git -c "$sandbox/work" lazygit
check "a window that is already there is left alone" \
  test "$("$RESTORE" restore >/dev/null; tm list-windows -t =work -F '#{window_name}' | grep -cx git)" = 1

# --- a task that was finished in between ---------------------------------------------------

rm -rf "$sandbox/work.worktrees/fix-runner"
tm kill-server
"$RESTORE" restore >/dev/null
settle "tm has-session -t =work"
check "a tab whose worktree has gone comes back as an ordinary tab, not a broken one" \
  test -z "$(tm list-windows -a -F '#{@worktree}' | grep .)"

# --- wired in ------------------------------------------------------------------------------

conf="$ROOT/config/tmux/tmux.conf"
for hook in window-linked window-unlinked session-created session-closed window-renamed; do
  check "a change of $hook asks for a save" \
    grep -q "^set-hook -g $hook\[[0-9]*\] 'run-shell -b \"desktop-tmux-restore save --settle\"'" "$conf"
done
check "the login script restores" grep -q '^desktop-tmux-restore restore' "$ROOT/bin/desktop-workspace-start"

finish
