#!/usr/bin/env bash

# Three idle costs, in files copied to ~/.config once: lazygit's timers, the tmux hooks that
# let a sidebar off screen stop asking tmux whether it is on screen, and nvim's redraw
# timers. Each is added only where it is missing, so a file edited by hand keeps its edits.
REPO="$HOME/.local/share/desktop/config"

LAZYGIT="$HOME/.config/lazygit/config.yml"
if [[ -f $LAZYGIT ]] && ! grep -q '^refresher:' "$LAZYGIT"; then
  printf '\n' >>"$LAZYGIT"
  sed -n '/^# Every repository.s session keeps a lazygit/,/^  externalChangeCheckInterval:/p' "$REPO/lazygit/config.yml" >>"$LAZYGIT"
  echo "  lazygit refreshes every 30s and fetches every 10 minutes; restart it to apply"
fi

TMUX_CONF="$HOME/.config/tmux/tmux.conf"
if [[ -f $TMUX_CONF ]] && ! grep -q 'desktop-tmux-view' "$TMUX_CONF"; then
  printf '\n' >>"$TMUX_CONF"
  sed -n '/^# What is on screen changed\. A sidebar/,/^set-hook -g window-pane-changed\[5\]/p' "$REPO/tmux/tmux.conf" >>"$TMUX_CONF"
  tmux source-file "$TMUX_CONF" 2>/dev/null || true
  echo "  tmux says when what is on screen changes, so hidden sidebars stop asking"
fi

PLUGINS="$HOME/.config/nvim/lua/plugins"
if [[ -d $PLUGINS && ! -e $PLUGINS/idle-timers.lua ]]; then
  cp "$REPO/nvim/lua/plugins/idle-timers.lua" "$PLUGINS/"
  echo "  nvim wakes less often when idle, from its next start"
fi
exit 0
