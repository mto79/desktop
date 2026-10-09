#!/usr/bin/env bash
# Tabs in a terminal pane: the shell strip of an agent window, or any pane at a shell.
#
# Against a real tmux server on a socket of its own, for the reason agent-layout-test.sh
# gives: what matters is what only tmux can answer -- that the shell which was there is
# still running as the first tab, that the pane really did become a client, and that the
# keys reach the terminal from the terminal and the agents from everywhere else.
source "$(dirname "$0")/lib.sh"

require tmux || finish

TMUX_BIN=$(command -v tmux)
SOCKET="desktop-term-test-$$"

sandbox=$(mktemp -d)
trap '"$TMUX_BIN" -L "$SOCKET" kill-server 2>/dev/null; rm -f "${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/$SOCKET"; rm -rf "$sandbox"' EXIT

stubs="$sandbox/bin"
mkdir -p "$stubs" "$sandbox/work"

cat >"$stubs/tmux" <<STUB
#!/usr/bin/env bash
exec "$TMUX_BIN" -L "$SOCKET" "\$@"
STUB
cat >"$stubs/desktop-agent" <<'STUB'
#!/usr/bin/env bash
exec sleep 300
STUB
chmod +x "$stubs"/*

# XDG_CONFIG_HOME as well as HOME: tmux looks there first, and would otherwise load the
# tmux.conf deployed on this machine, hooks and all.
export HOME="$sandbox" XDG_CONFIG_HOME="$sandbox/config" PATH="$stubs:$ROOT/bin:$PATH" EDITOR=true SHELL=/bin/bash
tm() { "$TMUX_BIN" -L "$SOCKET" "$@"; }

settle() {
  local i
  for i in $(seq 50); do
    eval "$1" >/dev/null 2>&1 && return 0
    sleep 0.1
  done
  return 1
}

tm new-session -d -s work -n ide -c "$sandbox/work" -x 160 -y 50
desktop-agent-layout work:ide claude

shell=$(tm list-panes -t work:ide -F '#{pane_id} #{@term_pane}' | awk 'NF > 1 { print $1 }')
column=$(tm list-panes -t work:ide -F '#{pane_id} #{@ai_column}' | awk 'NF > 1 { print $1 }')
check "the layout marks its shell as the window's terminal" test -n "$shell"
check "and the keys know it for one" test "$(desktop-terminal-tabs kind "$shell")" = terminal
check "the column is the agents', not a terminal" test "$(desktop-terminal-tabs kind "$column")" = agents

# Before anything is asked for the pane is a plain shell: no session, no bar, no client.
check "a terminal with one shell has no session behind it" \
  lacks '^term-' <<<"$(tm list-sessions -F '#{session_name}')"

# --- the second terminal ------------------------------------------------------------------

desktop-terminal-tabs new "$shell"
session=$(tm list-sessions -F '#{session_name}' | grep '^term-')
check "asking for another makes a session for the tabs" test -n "$session"
check "with two of them" test "$(tm list-windows -t "=$session" | wc -l)" = 2
check "the shell that was there is the first, still running" \
  test "$(tm list-windows -t "=$session" -F '#{pane_id}' | head -1)" = "$shell"
check "and the new one is on top" \
  test "$(tm display-message -p -t "=$session:" '#{pane_id}')" != "$shell"
check "the window keeps its three panes" test "$(tm list-panes -t work:ide | wc -l)" = 3
holder=$(tm list-panes -t work:ide -F '#{pane_id} #{@term_tabs}' | awk 'NF > 1 { print $1 }')
check "the pane in its place shows the tabs" \
  grep -q 'desktop-terminal-tabs attach' <<<"$(tm display-message -p -t "$holder" '#{pane_start_command}')"
settle "tm list-clients -F '#{client_session}' | grep -qx '$session'"
check "through a client of its own" \
  test "$(tm list-clients -F '#{client_session}' | grep -cx "$session")" = 1
check "with a bar, now there is something to choose" \
  test "$(tm show-options -v -t "=$session:" status)" = on
check "the focus stays in the terminal" test "$(tm display-message -p -t work:ide '#{pane_id}')" = "$holder"

desktop-terminal-tabs new "$holder"
check "a third is another tab, not another session" \
  test "$(tm list-windows -t "=$session" | wc -l)$(tm list-sessions -F '#{session_name}' | grep -c '^term-')" = 31

# --- what a tab is called ------------------------------------------------------------------

# Left to tmux every tab is "fish". A tab says where its shell is, or what it is running.
check "a tab is named after where its shell is" \
  grep -q 'b:pane_current_path' <<<"$(tm show-options -wv -t "=$session:" automatic-rename-format)"
check "the first one too, the shell that was already there" \
  grep -q 'pane_current_command' <<<"$(tm show-options -wv -t "$shell" automatic-rename-format)"

# --- beside a task -------------------------------------------------------------------------

# With a task's tab on top of the AI column, the next terminal opens in that task's
# worktree: its agent is there, and this is where its tests are run.
mkdir -p "$sandbox/work.worktrees/fix"
ai_session=$(tm list-sessions -F '#{session_name}' | grep '^ai-')
settle "tm list-clients -F '#{client_session}' | grep -qx '$ai_session'"
tm set-option -w -t "=$ai_session:" @worktree "$sandbox/work.worktrees/fix"
check "the task on show is the one in the column's top tab" \
  test "$(desktop-worktree here "$holder")" = "$sandbox/work.worktrees/fix"
desktop-terminal-tabs new "$holder"
check "and a new terminal opens beside it" \
  test "$(tm display-message -p -t "=$session:" '#{pane_start_path}')" = "$sandbox/work.worktrees/fix"
tm set-option -wu -t "=$ai_session:" @worktree
desktop-terminal-tabs close "$holder"

# --- the terminal, full size ---------------------------------------------------------------

editor=$(tm list-panes -t work:ide -F '#{pane_id}' | head -1)
tm select-pane -t "$editor"
desktop-terminal-tabs zoom "$editor"
check "prefix + Z zooms the window" test "$(tm display-message -p -t work:ide '#{window_zoomed_flag}')" = 1
check "on its terminal, from wherever the focus was" \
  test "$(tm display-message -p -t work:ide '#{pane_id}')" = "$holder"
desktop-terminal-tabs zoom "$holder"
check "and again gives the window back" test "$(tm display-message -p -t work:ide '#{window_zoomed_flag}')" = 0
check "with the focus where it was" test "$(tm display-message -p -t work:ide '#{pane_id}')" = "$editor"
tm select-pane -t "$holder"

# --- a command that ended while nobody was looking -----------------------------------------

# Three tabs, the third on top: the first is one nobody is looking at.
desktop-terminal-tabs finished "$shell" 0
check "a long command ending in a tab that is not on top marks it done" \
  test "$(tm show-options -wqv -t "$shell" @agent_state)" = done
desktop-terminal-tabs finished "$shell" 2
check "or failed, when it ended badly" test "$(tm show-options -wqv -t "$shell" @agent_state)" = failed
tm set-option -wu -t "$shell" @agent_state
top_pane=$(tm display-message -p -t "=$session:" '#{pane_id}')
desktop-terminal-tabs finished "$top_pane" 0
check "the tab on top, in a window on show, is being looked at and gets none" \
  test -z "$(tm show-options -wqv -t "$top_pane" @agent_state)"
check "the bar has a mark for failed" grep -q 'failed},#\[fg=#{@agent-waiting-colour}\]✗' "$ROOT/config/tmux/tmux.conf"
check "and arriving at the tab clears it, as it does done" \
  test "$(grep -c "m/r:^(done|failed)\$,#{@agent_state}}\" \"set -wu @agent_state ; run -b" "$ROOT/config/tmux/tmux.conf")" = 3
check "the shell reports a command that ran a while" \
  grep -q 'desktop-terminal-tabs finished $TMUX_PANE' "$ROOT/config/fish/conf.d/tmux-done.fish"

# --- moving and closing -------------------------------------------------------------------

top=$(tm display-message -p -t "=$session:" '#{window_index}')
desktop-terminal-tabs tab "$holder" previous
check "prefix + Tab moves between a terminal's tabs" \
  test "$(tm display-message -p -t "=$session:" '#{window_index}')" != "$top"
desktop-terminal-tabs tab "$holder" next

ai=$(tm list-sessions -F '#{session_name}' | grep '^ai-')
before=$(tm list-windows -t "=$ai" | wc -l)
desktop-terminal-tabs new "$column"
check "from the column the same key is still another agent" \
  test "$(tm list-windows -t "=$ai" | wc -l)" = $((before + 1))
check "and not another terminal" test "$(tm list-windows -t "=$session" | wc -l)" = 3

desktop-terminal-tabs close "$holder"
desktop-terminal-tabs close "$holder"
check "prefix + x closes the tab on top" test "$(tm list-windows -t "=$session" | wc -l)" = 1
check "the first shell is the one left" \
  test "$(tm display-message -p -t "=$session:" '#{pane_id}')" = "$shell"
check "and the bar goes when there is nothing to choose" \
  test "$(tm show-options -v -t "=$session:" status)" = off

# --- what the rest of the desktop sees ----------------------------------------------------

check "prefix + s does not offer a terminal's tabs as a session" \
  lacks 'term-' <<<"$(desktop-agent-tabs sessions)"
check "nor does prefix + S take them for an agent's" lacks 'term-' <<<"$(desktop-agent-tabs tabs)"

# --- a pane no layout made ----------------------------------------------------------------

tm new-window -d -t work: -n busy "sleep 300"
busy=$(tm list-panes -t work:busy -F '#{pane_id}')
# Not by what is running: the shell runs the command and tmux reports the shell.
check "a pane started with a command of its own is not a terminal" \
  test "$(desktop-terminal-tabs kind "$busy")" = agents
tm new-window -d -t work: -n plain -c "$sandbox/work"
plain=$(tm list-panes -t work:plain -F '#{pane_id}')
check "a pane started as a shell is one, layout or not" \
  test "$(desktop-terminal-tabs kind "$plain")" = terminal

# --- the sessions do not outlive the pane -------------------------------------------------

desktop-terminal-tabs gc
check "the collector leaves the tabs of a pane that is still there" tm has-session -t "=$session"
tm kill-window -t work:ide
desktop-terminal-tabs gc
check "and takes them once the pane has gone" lacks -x "$session" <<<"$(tm list-sessions -F '#{session_name}')"

finish
