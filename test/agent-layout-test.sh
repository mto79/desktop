#!/usr/bin/env bash
# The agent window layout, and swapping the agent in a pane.
#
# Against a real tmux server on a socket of its own, because what is worth checking is
# what only tmux can answer: that three panes come out in the right order, that the pane
# option survives the respawn it is read back after, and that the swap picks the agent
# pane out of the window when the focus is somewhere else -- which it always is, since
# the layout leaves it in the editor.
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

tm new-session -d -s work -n ide -c "$sandbox/work"
desktop-agent-layout work:ide claude

panes() { tm list-panes -t work:ide -F "$1" | tr '\n' ' ' | sed 's/ $//'; }

check "the layout is editor, shell and agent" test "$(tm list-panes -t work:ide | wc -l)" = 3
check "the focus is left in the editor" \
  test "$(tm display-message -p -t work:ide '#{pane_index}')" = 1

agent=$(tm list-panes -t work:ide -F '#{pane_id} #{@agent}' | awk 'NF > 1 { print $1 }')
check "exactly one pane is marked as the agent's" test "$(wc -w <<<"$agent")" = 1
check "the agent pane says which agent it holds" \
  test "$(tm display-message -p -t "$agent" '#{@agent}')" = claude
check "the agent is the pane's own command, not typed into a shell" \
  grep -q 'desktop-agent claude' <<<"$(tm display-message -p -t "$agent" '#{pane_start_command}')"
check "the agent pane outlives the agent" \
  test "$(tm display-message -p -t "$agent" '#{?pane_dead,dead,alive}')" = alive
check "a fresh directory starts claude without --continue" \
  lacks -- '--continue' <<<"$(tm display-message -p -t "$agent" '#{pane_start_command}')"

# The cycle, from the editor pane: the binding passes whichever pane is focused, and
# that is the editor, so finding the agent pane is the whole job.
editor=$(tm list-panes -t work:ide -F '#{pane_id}' | head -1)
desktop-agent-swap "$editor"
check "swapping from the editor pane swaps the agent pane" \
  test "$(tm display-message -p -t "$agent" '#{@agent}')" = opencode
check "swapping does not open a pane" test "$(tm list-panes -t work:ide | wc -l)" = 3
check "the cycled pane runs the next agent" \
  grep -q 'desktop-agent opencode' <<<"$(tm display-message -p -t "$agent" '#{pane_start_command}')"

# Coming back to claude. First with only `claude -p` transcripts in the directory --
# lazygit's commit messages leave those, marked sdk-cli, and --continue skips them, so
# passing it there kills claude with "no conversation found". Two real repos on the
# machine this was written on had nothing else.
slug=$(printf '%s' "$sandbox/work" | sed 's/[^A-Za-z0-9]/-/g')
mkdir -p "$HOME/.claude/projects/$slug"
printf '{"type":"user","entrypoint":"sdk-cli"}\n' >"$HOME/.claude/projects/$slug/lazygit.jsonl"
desktop-agent-swap "$editor" claude
check "a directory with only claude -p transcripts is not continued" \
  lacks -- '--continue' <<<"$(tm display-message -p -t "$agent" '#{pane_start_command}')"
desktop-agent-swap "$editor" opencode

# Then with an interactive conversation there to resume.
printf '{"type":"user","entrypoint":"cli"}\n' >"$HOME/.claude/projects/$slug/a.jsonl"
desktop-agent-swap "$editor" claude
check "naming claude returns to it" \
  test "$(tm display-message -p -t "$agent" '#{@agent}')" = claude
check "a conversation in that directory is continued rather than lost" \
  grep -q -- '--continue' <<<"$(tm display-message -p -t "$agent" '#{pane_start_command}')"
check "codex is not given a resume flag, which is not scoped to this directory" \
  lacks resume <<<"$(desktop-agent-swap "$editor" codex >/dev/null && tm display-message -p -t "$agent" '#{pane_start_command}')"
desktop-agent-swap "$editor" claude

# A dead pane has no current path. Swapping it must start the next agent where the pane
# was, not in whatever directory desktop-agent-swap happened to be run from -- the tmux
# binding runs it from the server's own cwd.
tm respawn-pane -k -t "$agent" -c "$sandbox/work" "true"
for _ in $(seq 20); do [[ $(tm display-message -p -t "$agent" '#{pane_dead}') == 1 ]] && break; sleep 0.1; done
(cd / && desktop-agent-swap "$editor" opencode)
check "a dead pane's agent starts in the pane's directory, not the caller's" \
  test "$(tm display-message -p -t "$agent" '#{pane_start_path}')" = "$sandbox/work"
desktop-agent-swap "$editor" claude

# A swap takes the replaced agent's mark off the tab. Killing an agent reports nothing, so
# otherwise the tab would keep saying "working" about a claude that is gone.
tm set-option -w -t "$agent" @agent_state working
desktop-agent-swap "$editor" opencode
check "swapping clears the replaced agent's mark from the tab" \
  test -z "$(tm show-options -wqv -t "$agent" @agent_state)"
desktop-agent-swap "$editor" claude

# All the way round the rotation, from a known start: three presses of prefix+a come
# back to where they began.
desktop-agent-swap "$editor" claude
desktop-agent-swap "$editor"
check "the first press reaches opencode" \
  test "$(tm display-message -p -t "$agent" '#{@agent}')" = opencode
desktop-agent-swap "$editor"
check "the second reaches codex" \
  test "$(tm display-message -p -t "$agent" '#{@agent}')" = codex
desktop-agent-swap "$editor"
check "the third comes back round to claude" \
  test "$(tm display-message -p -t "$agent" '#{@agent}')" = claude

# Picking one by name, the way the prefix+A menu does: from the focused pane, which is
# still the editor, so it has to land on the agent pane and nowhere else.
desktop-agent-swap "$editor" codex
check "naming an agent from the editor pane changes the agent pane" \
  test "$(tm display-message -p -t "$agent" '#{@agent}')" = codex
check "naming an agent leaves the editor alone" \
  test -z "$(tm display-message -p -t "$editor" '#{@agent}')"
check "every name in the rotation is accepted" \
  test "$(desktop-agent-swap "$editor" x >/dev/null && tm display-message -p -t "$agent" '#{@agent}')" = codex
check "a name outside it is refused" \
  lacks . <<<"$(desktop-agent-swap "$editor" gemini 2>/dev/null || true)"

# --here is the only form that takes a pane at its word, and it is how a first agent is
# put anywhere. Without it a window with no agent pane must be left alone rather than
# have whatever is focused respawned out from under it.
tm new-window -t work: -n plain -c "$sandbox/work"
plain=$(tm display-message -p -t work:plain '#{pane_id}')
check "a bare swap refuses a window with no agent pane" \
  lacks . <<<"$(desktop-agent-swap "$plain" 2>/dev/null || true)"
check "naming an agent does not make it take the pane over either" \
  lacks . <<<"$(desktop-agent-swap "$plain" claude 2>/dev/null || true)"
check "it leaves that pane alone" test -z "$(tm display-message -p -t "$plain" '#{@agent}')"
desktop-agent-swap --here "$plain" cx
check "--here starts one there" \
  test "$(tm display-message -p -t "$plain" '#{@agent}')" = claude
check "--here without an agent is refused" \
  lacks . <<<"$(desktop-agent-swap --here "$plain" 2>/dev/null || true)"

# The second agent, stacked under the first.
tm new-window -t work: -n both -c "$sandbox/work"
desktop-agent-layout work:both claude opencode
check "a second agent makes a fourth pane" test "$(tm list-panes -t work:both | wc -l)" = 4
check "both agents are marked" \
  test "$(tm list-panes -t work:both -F '#{@agent}' | grep -c .)" = 2

finish
