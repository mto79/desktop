#!/usr/bin/env bash

# OpenCode, from npm, into the user's own prefix -- for the reason codex.sh gives: it
# updates itself, and cannot when it lives in a directory only root may write.

set -euo pipefail

echo "Installing OpenCode"
npm config set prefix "$HOME/.local"
npm i -g opencode-ai
echo "OpenCode $(opencode --version 2>/dev/null || echo installed)"
