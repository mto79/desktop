#!/usr/bin/env bash

# SUPER+Return goes through desktop-launch-terminal, which opens tmux on the workspace
# tmux lives on. bindings.conf is copied to ~/.config once and is the user's from then
# on, so only the line as it was shipped is rewritten; a binding somebody changed stays.

BINDINGS="$HOME/.config/hypr/bindings.conf"

if [[ ! -f $BINDINGS ]]; then
  echo "  no bindings.conf to update"
elif grep -q 'exec, desktop-launch-terminal$' "$BINDINGS"; then
  echo "  the terminal binding already opens tmux on its workspace"
elif grep -q '^bindd = SUPER, return, Terminal, exec, \$terminal --working-directory="\$(desktop-cmd-terminal-cwd)"$' "$BINDINGS"; then
  sed -i 's|^bindd = SUPER, return, Terminal, exec, \$terminal --working-directory="\$(desktop-cmd-terminal-cwd)"$|bindd = SUPER, return, Terminal, exec, desktop-launch-terminal|' "$BINDINGS" || exit 1
  hyprctl reload >/dev/null 2>&1 || true
  echo "  the terminal binding opens tmux on its workspace"
else
  echo "  the terminal binding was changed by hand; left alone"
fi
