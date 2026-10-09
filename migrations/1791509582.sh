#!/usr/bin/env bash

# The bar's AI module turns green and breathes when an agent has finished a turn nobody has
# looked at yet. Both halves of that live in files that are copied to ~/.config once, so a
# machine installed earlier gets them here.

# The state's colour and its place among the ones that breathe -- unless the module is gone
# or already says something about "done", in which case it is someone's own and is left.
CONFIG="$HOME/.config/desktop/shell.json"
if [[ -f $CONFIG ]] && jq -e '[.. | objects | select(.id? == "ai" and .type? == "command" and (.colors.done? | not))] | length > 0' "$CONFIG" >/dev/null; then
  tmp=$(mktemp)
  jq '(.. | objects | select(.id? == "ai" and .type? == "command" and (.colors.done? | not))) |=
        (.colors.done = "good" | .pulse = ((.pulse // []) + ["done"]))' "$CONFIG" >"$tmp" &&
    mv "$tmp" "$CONFIG" && echo "  the AI module says when an agent has finished"
  rm -f "$tmp"
fi

# And arriving at the agent's window tells the bar, so it stops at once rather than at its
# next poll. Only the three hooks as they were shipped are rewritten.
TMUX_CONF="$HOME/.config/tmux/tmux.conf"
if [[ -f $TMUX_CONF ]] && ! grep -q 'refreshWidget ai' "$TMUX_CONF"; then
  sed -i 's|^\(set-hook -g [a-z-]* .if -F "#{m/r:^(done.failed)\$,#{@agent_state}}" "set -wu @agent_state\)".$|\1 ; run -b \\"desktop-shell shell refreshWidget ai >/dev/null 2>\&1\\""\x27|' "$TMUX_CONF"
  tmux source-file "$TMUX_CONF" 2>/dev/null || true
  echo "  and stops saying so when you look"
fi
