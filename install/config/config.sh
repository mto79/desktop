#!/usr/bin/env bash

xdg-user-dirs-update

# Copy over configs
mkdir -p ~/.config
cp -R ~/.local/share/desktop/config/* ~/.config/

# Use default bashrc
cp ~/.local/share/desktop/default/bashrc ~/.bashrc

# Enable the session ssh-agent. The unit and its environment.d drop-in are
# copied in above; enabling it is what puts SSH_AUTH_SOCK in the systemd user
# environment, where Hyprland -- and so KeePassXC's SSH agent integration --
# can inherit it.
systemctl --user daemon-reload
systemctl --user enable --now ssh-agent.service

# Claude Code's hooks, which report each session's state -- working, waiting on you,
# finished -- to the tmux tab, the AI panel, the bar and a notification when you are needed.
#
# settings.json cannot simply be copied from config/ like everything else: it carries
# machine state -- auth, the auto-mode environment -- alongside its configuration, and
# overwriting that on every install would lose it. desktop-agent-hooks merges the hooks in
# instead, and is safe to run again.
CLAUDE_SETTINGS="$HOME/.config/claude/settings.json"
mkdir -p "$(dirname "$CLAUDE_SETTINGS")"
[ -f "$CLAUDE_SETTINGS" ] || echo '{}' >"$CLAUDE_SETTINGS"
CLAUDE_CONFIG_DIR="$(dirname "$CLAUDE_SETTINGS")" ~/.local/share/desktop/bin/desktop-agent-hooks
