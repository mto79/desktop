#!/usr/bin/env bash

# opencode and codex report what they are doing, as claude does, so their tabs stop being
# shown idle: opencode through a plugin it loads from ~/.config/opencode/plugins (from its
# next start), codex through the notify program it runs when a turn ends.
PLUGIN="$HOME/.config/opencode/plugins/desktop-state.js"
if [[ -d $HOME/.config/opencode && ! -e $PLUGIN ]]; then
  mkdir -p "$(dirname "$PLUGIN")"
  cp "$HOME/.local/share/desktop/config/opencode/plugins/desktop-state.js" "$PLUGIN"
  echo "  opencode reports its state from its next start"
fi
"$HOME/.local/share/desktop/bin/desktop-agent-codex-notify" --wire
exit 0
