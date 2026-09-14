#!/usr/bin/env bash

set -euo pipefail

echo "📌 Installing Codex CLI ..."

# npm rather than the standalone installer, to match opencode.sh: both then live in
# /usr/local/bin and are upgraded the same way.
sudo npm i -g @openai/codex

echo "✔ Codex installed."
echo ""
echo "🎉 Installation Complete!"
echo "Restart your terminal"
echo ""
echo "You can now run Codex with:"
echo "  codex --version"
echo ""
echo "To authenticate, run:"
echo "  codex login"
