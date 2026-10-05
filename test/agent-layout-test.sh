#!/usr/bin/env bash
# The agent window: its shape, the column of tabs on the right, and swapping the agent.
#
# Against a real tmux server on a socket of its own, because what is worth checking is
# what only tmux can answer -- where the panes come out, that the column really does
# attach a client of its own, that a pane option survives the respawn it is read back
# after, and that each model keeps the tabs it had.
#
# The agents themselves are stubbed. Nothing here may start a real claude.
source "$(dirname "$0")/lib.sh"

require tmux || finish

TMUX_BIN=$(command -v tmux)
SOCKET="desktop-test-$$"

sandbox=$(mktemp -d)
# kill-server alone leaves the socket file behind in /tmp/tmux-*/, one per run.
trap '"$TMUX_BIN" -L "$SOCKET" kill-server 2>/dev/null; rm -f "${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/$SOCKET"; rm -rf "$sandbox"' EXIT

stubs="$sandbox/bin"
mkdir -p "$stubs" "$sandbox/work"

# Every tmux the scripts under test run has to land on this server, not on the one the
# suite may itself be running inside.
cat >"$stubs/tmux" <<STUB
#!/usr/bin/env bash
exec "$TMUX_BIN" -L "$SOCKET" "\$@"
STUB
cat >"$stubs/desktop-agent" <<'STUB'
#!/usr/bin/env bash
exec sleep 300
STUB
chmod +x "$stubs"/*

# HOME in the sandbox keeps the user's tmux.conf out of it, and keeps claude_has_history
# answering no until this test says otherwise. EDITOR too: the editor pane is the one
# thing still started with send-keys, and it must not open anything real.
export HOME="$sandbox" PATH="$stubs:$ROOT/bin:$PATH" EDITOR=true
tm() { "$TMUX_BIN" -L "$SOCKET" "$@"; }

# The column attaches its client on its own time, so anything that asks about it waits.
settle() {
  local i
  for i in $(seq 50); do
    eval "$1" >/dev/null 2>&1 && return 0
    sleep 0.1
  done
  return 1
}

tm new-session -d -s work -n ide -c "$sandbox/work" -x 120 -y 40
desktop-agent-layout work:ide claude

# --- the shape ----------------------------------------------------------------------------

check "the layout is editor, shell and column" test "$(tm list-panes -t work:ide | wc -l)" = 3
check "the focus is left in the editor" \
  test "$(tm display-message -p -t work:ide '#{pane_index}')" = 1

column=$(tm list-panes -t work:ide -F '#{pane_id} #{@ai_column}' | awk 'NF > 1 { print $1; exit }')
check "one pane is the AI column" test "$(wc -w <<<"$column")" = 1

geometry() { tm display-message -p -t "$1" "$2"; }
editor=$(tm list-panes -t work:ide -F '#{pane_id}' | head -1)
# The column runs the full height on the right; the shell sits under the editor only, and
# not under the column as well. This is the arrangement, not an accident of split order.
check "the column runs the full height of the window" \
  test "$(geometry "$column" '#{pane_height}')" = "$(geometry work:ide '#{window_height}')"
check "the column is on the right" \
  test "$(geometry "$column" '#{pane_left}')" -gt "$(geometry "$editor" '#{pane_left}')"
shell=$(tm list-panes -t work:ide -F '#{pane_id} #{pane_top}' | sort -k2 -rn | awk 'NR == 1 { print $1 }')
check "the shell is under the editor and no wider" \
  test "$(geometry "$shell" '#{pane_width}')" = "$(geometry "$editor" '#{pane_width}')"

# --- the column's own client ---------------------------------------------------------------

group=$(tm display-message -p -t "$column" '#{@ai_column}')
session="ai-$group-claude"
check "the column pane runs the tabs, not an agent" \
  grep -q 'desktop-agent-tabs attach' <<<"$(tm display-message -p -t "$column" '#{pane_start_command}')"
check "a session was made for the model it was asked for" \
  tm has-session -t "=$session"
settle "tm list-clients -F '#{client_session}' | grep -qx '$session'"
check "the column holds a client of its own, looking at that session" \
  test "$(tm list-clients -F '#{client_session}' | grep -cx "$session")" = 1
check "its status line is the tab bar, at the bottom" \
  test "$(tm show-options -qv -t "=$session:" status-position)" = bottom
check "and carries nothing but the tabs" \
  test -z "$(tm show-options -qv -t "=$session:" status-left)$(tm show-options -qv -t "=$session:" status-right)"
# Without this the client falls back to another session when the last tab closes -- which
# can be the session the column is in, and no pane can display the window holding it.
check "it detaches rather than wandering when the last tab closes" \
  test "$(tm show-options -qv -t "=$session:" detach-on-destroy)" = on

agent=$(tm display-message -p -t "=$session:" '#{pane_id}')
check "the tab holds the agent" test "$(tm display-message -p -t "$agent" '#{@agent}')" = claude
check "the agent is the pane's own command, not typed into a shell" \
  grep -q 'desktop-agent claude' <<<"$(tm display-message -p -t "$agent" '#{pane_start_command}')"
check "the agent's pane outlives the agent" \
  test "$(tm display-message -p -t "$agent" '#{?pane_dead,dead,alive}')" = alive
check "a fresh directory starts claude without --continue" \
  lacks -- '--continue' <<<"$(tm display-message -p -t "$agent" '#{pane_start_command}')"
check "the session knows which column it belongs to" \
  test "$(tm show-options -qv -t "=$session:" @ai_group)" = "$group"

# --- tabs ---------------------------------------------------------------------------------

# prefix + t, from the editor: the binding passes whichever pane has the focus.
desktop-agent-tabs new "$editor"
check "another tab is another window of that session" \
  test "$(tm list-windows -t "=$session" | wc -l)" = 2
check "the new tab runs the same model" \
  test "$(tm list-windows -t "=$session" -F '#{@agent}' | grep -cx claude)" = 2
check "and the window keeps its three panes" test "$(tm list-panes -t work:ide | wc -l)" = 3

first=$(tm display-message -p -t "=$session:" '#{window_index}')
desktop-agent-tabs tab "$editor" next
second=$(tm display-message -p -t "=$session:" '#{window_index}')
check "prefix + Tab moves to another tab" test "$first" != "$second"
desktop-agent-tabs tab "$editor" previous
check "and back again" test "$(tm display-message -p -t "=$session:" '#{window_index}')" = "$first"

# --- models, each with its own tabs --------------------------------------------------------

desktop-agent-swap "$editor" >/dev/null
settle "tm list-clients -F '#{client_session}' | grep -qx 'ai-$group-opencode'"
check "prefix + a moves the column to the next model" \
  test "$(tm list-clients -F '#{client_session}' | grep -cx "ai-$group-opencode")" = 1
check "which is a session of its own" tm has-session -t "=ai-$group-opencode"
check "and it did not respawn the column out from under the tabs" \
  grep -q 'desktop-agent-tabs attach' <<<"$(tm display-message -p -t "$column" '#{pane_start_command}')"
check "the column records the model it is on" \
  test "$(tm display-message -p -t "$column" '#{@ai_model}')" = opencode

desktop-agent-swap "$editor" claude >/dev/null
settle "tm list-clients -F '#{client_session}' | grep -qx '$session'"
check "naming a model comes back to the tabs it had" \
  test "$(tm list-windows -t "=$session" | wc -l)" = 2
check "a name outside the rotation is refused" \
  lacks . <<<"$(desktop-agent-swap "$editor" gemini 2>/dev/null || true)"

# --- going to an agent ---------------------------------------------------------------------

# An agent in a tab cannot be reached by switching a client to its session: that session
# is as narrow as the column and already has one. The window with the column is where the
# outer client goes, and the column's own client goes to the tab.
tm select-window -t work:ide
other=$(tm list-windows -t "=$session" -F '#{window_index}' | tail -1)
tm new-window -t work: -n elsewhere
tab_pane=$(tm display-message -p -t "=$session:$other" '#{pane_id}')
desktop-agent-tabs jump "$tab_pane" 2>/dev/null
check "a jump puts the outer session back on the window with the column" \
  test "$(tm display-message -p -t work: '#{window_name}')" = ide
check "and the column's client on the tab that was asked for" \
  test "$(tm display-message -p -t "=$session:" '#{window_index}')" = "$other"
tm kill-window -t work:elsewhere

# --- a second agent -----------------------------------------------------------------------

tm new-window -t work: -n both -c "$sandbox/work"
desktop-agent-layout work:both claude opencode
both=$(tm list-panes -t work:both -F '#{pane_id} #{@ai_column}' | awk 'NF > 1 { print $1; exit }')
group2=$(tm display-message -p -t "$both" '#{@ai_column}')
check "a second agent is a second set of tabs, not a fourth pane" \
  test "$(tm list-panes -t work:both | wc -l)" = 3
check "and both models are ready to switch to" \
  test "$(tm has-session -t "=ai-$group2-claude" && tm has-session -t "=ai-$group2-opencode" && echo both)" = both

# --- claude's --continue, on the pane that now holds it ------------------------------------

# First with only `claude -p` transcripts in the directory -- lazygit's commit messages
# leave those, marked sdk-cli, and --continue skips them, so passing it there kills claude
# with "no conversation found".
slug=$(printf '%s' "$sandbox/work" | sed 's/[^A-Za-z0-9]/-/g')
mkdir -p "$HOME/.claude/projects/$slug"
printf '{"type":"user","entrypoint":"sdk-cli"}\n' >"$HOME/.claude/projects/$slug/lazygit.jsonl"
desktop-agent-swap --here "$agent" claude >/dev/null
check "a directory with only claude -p transcripts is not continued" \
  lacks -- '--continue' <<<"$(tm display-message -p -t "$agent" '#{pane_start_command}')"
printf '{"type":"user","entrypoint":"cli"}\n' >"$HOME/.claude/projects/$slug/a.jsonl"
desktop-agent-swap --here "$agent" claude >/dev/null
check "a conversation in that directory is continued rather than lost" \
  grep -q -- '--continue' <<<"$(tm display-message -p -t "$agent" '#{pane_start_command}')"
check "codex is not given a resume flag, which is not scoped to this directory" \
  lacks resume <<<"$(desktop-agent-swap --here "$agent" codex >/dev/null && tm display-message -p -t "$agent" '#{pane_start_command}')"

# A swap takes the replaced agent's mark off the tab. Killing an agent reports nothing, so
# otherwise the tab would keep saying "working" about a claude that is gone.
tm set-option -w -t "$agent" @agent_state working
desktop-agent-swap --here "$agent" claude >/dev/null
check "swapping clears the replaced agent's mark from the tab" \
  test -z "$(tm show-options -wqv -t "$agent" @agent_state)"

# A dead pane has no current path. Swapping it must start the next agent where the pane
# was, not in whatever directory desktop-agent-swap happened to be run from -- the tmux
# binding runs it from the server's own cwd.
tm respawn-pane -k -t "$agent" -c "$sandbox/work" "true"
for _ in $(seq 20); do [[ $(tm display-message -p -t "$agent" '#{pane_dead}') == 1 ]] && break; sleep 0.1; done
(cd / && desktop-agent-swap --here "$agent" opencode >/dev/null)
check "a dead pane's agent starts in the pane's directory, not the caller's" \
  test "$(tm display-message -p -t "$agent" '#{pane_start_path}')" = "$sandbox/work"

# --- a plain agent pane, which --here still makes ------------------------------------------

tm new-window -t work: -n plain -c "$sandbox/work"
plain=$(tm display-message -p -t work:plain '#{pane_id}')
check "a bare swap refuses a window with no agent in it" \
  lacks . <<<"$(desktop-agent-swap "$plain" 2>/dev/null || true)"
check "it leaves that pane alone" test -z "$(tm display-message -p -t "$plain" '#{@agent}')"
desktop-agent-swap --here "$plain" cx >/dev/null
check "--here starts one there" test "$(tm display-message -p -t "$plain" '#{@agent}')" = claude
check "--here without an agent is refused" \
  lacks . <<<"$(desktop-agent-swap --here "$plain" 2>/dev/null || true)"
desktop-agent-swap "$plain" >/dev/null
check "and a window with a plain agent pane still cycles in place" \
  test "$(tm display-message -p -t "$plain" '#{@agent}')" = opencode

# --- which sessions the choosers show -------------------------------------------------------

# prefix + s is for the sessions you work in, and a column's tabs are not one of those.
# The filter is read back out of the config rather than written again here: it is a format
# string, and a format string that stops matching fails silently and shows everything.
filter_for() { grep -oP "^bind-key $1 choose-tree [^']*-f '\K[^']+" "$ROOT/config/tmux/tmux.conf"; }

plain=$(tm list-sessions -f "$(filter_for s)" -F '#{session_name}')
check "prefix + s shows the sessions you work in" grep -qx work <<<"$plain"
check "and leaves out the sessions behind a column" lacks '^ai-' <<<"$plain"

tabs=$(tm list-sessions -f "$(filter_for S)" -F '#{session_name}')
check "prefix + S shows the columns' sessions" grep -qx "ai-$group-claude" <<<"$tabs"
check "and nothing else" lacks -v '^ai-' <<<"$tabs"
check "every model of every column is in it" test "$(grep -c '^ai-' <<<"$tabs")" = 4
# Choosing one must go through its column: switching a client to a session as narrow as a
# column puts a second client on it and squeezes both.
chooser=$(grep '^bind-key S choose-tree' "$ROOT/config/tmux/tmux.conf")
check "choosing one goes through its column" grep -q 'desktop-agent-tabs jump' <<<"$chooser"
check "and not by switching a client to it" lacks 'switch-client' <<<"$chooser"

# --- the sessions do not outlive the window ------------------------------------------------

desktop-agent-tabs gc
check "the collector leaves the tabs of a window that is still there" \
  tm has-session -t "=$session"
tm kill-window -t work:ide
desktop-agent-tabs gc
check "and takes them once the column has gone" \
  lacks . <<<"$(tm has-session -t "=$session" 2>/dev/null && echo still-there)"
check "without touching another window's" tm has-session -t "=ai-$group2-claude"

finish
