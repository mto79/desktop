#!/usr/bin/env bash

set -euo pipefail

# Configurable section
INSTALL_PATH="/usr/local/bin"
# DEFAULT_PROVIDER="${DEFAULT_PROVIDER:-}"   # e.g., "openai" or "anthropic"
# OPENAI_KEY="${OPENAI_KEY:-}"
# ANTHROPIC_KEY="${ANTHROPIC_KEY:-}"

echo "📌 Installing OpenCode CLI ..."

# Download & run official install script
echo "🔽 Running official OpenCode install script..."
sudo npm i -g opencode-ai

echo "✔ OpenCode installed."
echo ""
echo "🎉 Installation Complete!"
echo "Restart your terminal"
echo ""
echo "You can now run OpenCode with:"
echo "  opencode --version"
echo ""
echo "To authenticate with providers, run:"
echo "  opencode auth login"
