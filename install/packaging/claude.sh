#!/usr/bin/env bash

set -e

echo "🔍 Checking for Node.js..."

if ! command -v node >/dev/null 2>&1; then
  echo "❌ Node.js not found. Installing..."

  if command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y nodejs npm
  else
    echo "❌ No supported package manager found."
    echo "Please install Node.js (>=18) manually:"
    echo "https://nodejs.org/"
    exit 1
  fi
else
  echo "✅ Node.js found: $(node --version)"
fi

echo "📦 Installing Claude Code..."
sudo npm install -g @anthropic-ai/claude-code

echo "🔎 Verifying installation..."
if command -v claude >/dev/null 2>&1; then
  echo "✅ Claude Code installed successfully!"
  claude --version
else
  echo "❌ Installation failed: 'claude' command not found"
  exit 1
fi

echo "🎉 Done! You can now run: claude"
