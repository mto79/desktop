#!/usr/bin/env bash

set -e

curl -fsSL https://claude.ai/install.sh | bash

echo "🔎 Verifying installation..."
if command -v claude >/dev/null 2>&1; then
  echo "✅ Claude Code installed successfully!"
  claude --version
  echo "✅ Symlink ~/.claude into your XDG structure"
  mv ~/.claude ~/.config/claude
  ln -sfn ~/.config/claude ~/.claude
else
  echo "❌ Installation failed: 'claude' command not found"
  exit 1
fi

echo "🎉 Done! You can now run: claude"
