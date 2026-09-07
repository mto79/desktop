#!/usr/bin/env bash

xdg-user-dirs-update

# Copy over configs
mkdir -p ~/.config
cp -R ~/.local/share/desktop/config/* ~/.config/

# Use default bashrc
cp ~/.local/share/desktop/default/bashrc ~/.bashrc

# Install lazygit helper scripts
mkdir -p ~/.local/bin
cp ~/.local/share/desktop/bin/lazygit-* ~/.local/bin/
chmod +x ~/.local/bin/lazygit-*

# Enable the session ssh-agent. The unit and its environment.d drop-in are
# copied in above; enabling it is what puts SSH_AUTH_SOCK in the systemd user
# environment, where Hyprland -- and so KeePassXC's SSH agent integration --
# can inherit it.
systemctl --user daemon-reload
systemctl --user enable --now ssh-agent.service

# Claude Code's Notification hook, which fires when an agent is waiting on an answer
# (bin/desktop-agent-notify turns that into a desktop notification).
#
# settings.json cannot simply be copied from config/ like everything else: it carries
# machine state -- auth, the auto-mode environment -- alongside its configuration, and
# overwriting that on every install would lose it. So merge in only this one hook, and
# only when it is absent, which also makes re-running the installer safe.
CLAUDE_SETTINGS="$HOME/.config/claude/settings.json"
mkdir -p "$(dirname "$CLAUDE_SETTINGS")"
[ -f "$CLAUDE_SETTINGS" ] || echo '{}' >"$CLAUDE_SETTINGS"
if ! jq -e '.hooks.Notification' "$CLAUDE_SETTINGS" >/dev/null 2>&1; then
  CLAUDE_TMP=$(mktemp)
  # $HOME stays literal in the JSON on purpose: the hook runs through a shell, and a
  # hook does not inherit the desktop session's PATH.
  jq '.hooks.Notification = [{hooks: [{type: "command", command: "$HOME/.local/share/desktop/bin/desktop-agent-notify", timeout: 5}]}]' \
    "$CLAUDE_SETTINGS" >"$CLAUDE_TMP" && mv "$CLAUDE_TMP" "$CLAUDE_SETTINGS"
fi
