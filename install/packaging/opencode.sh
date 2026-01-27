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

# Optional config: write provider config
# if [ -n "$DEFAULT_PROVIDER" ]; then
#   echo "🛠 Setting default provider to '${DEFAULT_PROVIDER}'"
#   cat > "${CONFIG_DIR}/opencode.json" <<EOF
# {
#   "\$schema": "https://opencode.ai/config.json",
#   "provider": {
#     "${DEFAULT_PROVIDER}": {}
#   }
# }
# EOF
#   echo "✔ Default provider configured."
# fi
#
# # Optional API keys export in shell profile
# PROFILE="${HOME}/.bashrc"
# if [ -n "$OPENAI_KEY" ]; then
#   echo "🔑 Configuring OpenAI API key..."
#   grep -q "OPENAI_API_KEY" "${PROFILE}" || echo "export OPENAI_API_KEY=\"${OPENAI_KEY}\"" >> "${PROFILE}"
#   echo "✔ OpenAI API key added."
# fi
# if [ -n "$ANTHROPIC_KEY" ]; then
#   echo "🔑 Configuring Anthropic API key..."
#   grep -q "ANTHROPIC_API_KEY" "${PROFILE}" || echo "export ANTHROPIC_API_KEY=\"${ANTHROPIC_KEY}\"" >> "${PROFILE}"
#   echo "✔ Anthropic API key added."
# fi

echo ""
echo "🎉 Installation Complete!"
echo "Restart your terminal"
echo ""
echo "You can now run OpenCode with:"
echo "  opencode --version"
echo ""
echo "To authenticate with providers, run:"
echo "  opencode auth login"
