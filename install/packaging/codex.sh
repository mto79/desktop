#!/usr/bin/env bash

# Codex CLI, from npm, into the user's own prefix.
#
# It used to go in with `sudo npm i -g`, which put it under /usr/local, owned by root. Codex
# updates itself: when a newer version is out it offers to, and runs `npm install -g` as
# whoever is running it. Against a root-owned directory that fails for want of
# administrator rights, in the middle of a session, and takes the agent's pane down with
# it. Installed where the user can write, the same update simply works.
#
# The prefix is npm's own setting rather than a flag on this one command, because the
# update is codex's command and not ours: it has to land in the same place without being
# told. ~/.local/bin is ahead of /usr/local/bin on PATH, so this copy is the one found.

set -euo pipefail

echo "Installing Codex CLI"
npm config set prefix "$HOME/.local"
npm i -g @openai/codex
echo "Codex $(codex --version 2>/dev/null || echo installed). Authenticate with: codex login"
