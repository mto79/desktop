#!/usr/bin/env bash
# desktop-agent-send: a message typed into another agent's pane, addressed as the sidebar
# shows it.
#
# On a tmux server of its own, with an agent column made by hand: a session "work" whose
# window holds the column, and the column's tabs as sessions of their own, an opencode tab
# and a claude tab. Each tab runs cat into a file, so what arrived can be read back.
source "$(dirname "$0")/lib.sh"

for tool in tmux python3; do require "$tool" || finish; done

sandbox=$(mktemp -d)
socket="agentsend-$$"
trap 'tmux -L "$socket" kill-server 2>/dev/null; rm -f "${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/$socket"; rm -rf "$sandbox"' EXIT
mkdir -p "$sandbox/path" "$sandbox/claude"

real=$(command -v tmux)
printf '#!/bin/sh\nexec %s -L %s "$@"\n' "$real" "$socket" >"$sandbox/path/tmux"
# No agents' own records: the column's tabs are listed from tmux alone.
printf '#!/bin/sh\necho %s\n' "'{\"sessions\": []}'" >"$sandbox/path/desktop-agent-sessions"
chmod +x "$sandbox/path/tmux" "$sandbox/path/desktop-agent-sessions"

export PATH="$sandbox/path:$PATH" CLAUDE_CONFIG_DIR="$sandbox/claude"
unset TMUX TMUX_PANE

# Windows counted from 1, as tmux.conf has them; the column's tab labels are those numbers.
tmux -f /dev/null new-session -d -s work -x 200 -y 50 "sleep 600" \; set -g base-index 1
tmux set-option -p -t work: @ai_column work-1
for model in opencode claude; do
  tmux new-session -d -s "ai-work-1-$model" -x 120 -y 40 "cat >$sandbox/$model.got"
  tmux set-option -w -t "ai-work-1-$model:1" @ai_group work-1
  tmux set-option -w -t "ai-work-1-$model:1" @ai_model "$model"
done

send() { python3 "$ROOT/bin/desktop-agent-send" "$@"; }
arrived() {
  for _ in $(seq 50); do
    grep -qF -- "$2" "$sandbox/$1.got" 2>/dev/null && return 0
    sleep 0.1
  done
  return 1
}

listed=$(send --list)
check "every agent is listed as the sidebar addresses it" \
  test "$(printf '%s\n' "$listed" | sort)" = "$(printf 'work\tclaude 1\nwork\topencode 1')"

send work "opencode 1" "the API changed, rebase" >/dev/null 2>&1
check "a message reaches the agent it names" arrived opencode "the API changed, rebase"
check "and not another" lacks "the API changed" "$sandbox/claude.got"

send work OpenCode-1 "said another way" >/dev/null 2>&1
check "the label may be typed without its space, or in another case" arrived opencode "said another way"

printf 'first line\nsecond line\n' | send work "opencode 1" >/dev/null 2>&1
check "a message on stdin arrives whole, every line of it" arrived opencode "second line"
check "its first line too" arrived opencode "first line"

tmux copy-mode -t ai-work-1-opencode:1
send work "opencode 1" "out of copy mode" >/dev/null 2>&1
check "a pane scrolled back in copy mode is taken out of it to receive" arrived opencode "out of copy mode"

pane=$(tmux display-message -p -t ai-work-1-claude:1 '#{pane_id}')
TMUX_PANE=$pane send work "opencode 1" "from one agent to another" >/dev/null 2>&1
check "sent from an agent's pane, it says who sent it" \
  arrived opencode "A message from the agent claude 1 in work."
check "and how to answer" arrived opencode 'To answer, run: desktop-agent-send work "claude 1"'

check "an agent that is not there is refused" \
  test "$(send work "codex 1" hi >/dev/null 2>&1; echo $?)" = 1
check "saying which agents the session does have" \
  test "$(send work "codex 1" hi 2>&1 >/dev/null)" = \
  "desktop-agent-send: no agent codex 1 in work; it has claude 1, opencode 1"
check "so is a session with no agents" \
  test "$(send elsewhere "opencode 1" hi >/dev/null 2>&1; echo $?)" = 1
check "and an agent sending to itself" \
  test "$(TMUX_PANE=$pane send work "claude 1" hi 2>&1)" = "desktop-agent-send: that is this agent"
check "and an empty message" test "$(send work "opencode 1" "" >/dev/null 2>&1; echo $?)" = 2

finish
