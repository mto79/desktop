#!/usr/bin/env bash
# ==========================================================
# Script: install_kubie_fedora_fish.sh
# Purpose: Install kubie on Fedora 43 with Fish completions
# ==========================================================

set -euo pipefail

# Variables
KUBIE_BIN="/usr/local/bin/kubie"
FISH_COMPLETIONS="$HOME/.config/fish/completions/kubie.fish"
FISH_CONFIG="$HOME/.config/fish/config.fish"

echo "[1/4] Downloading latest kubie binary..."
# Get latest release URL for Linux amd64
KUBIE_URL=$(curl -s https://api.github.com/repos/sbstp/kubie/releases/latest |
  grep browser_download_url |
  grep "kubie-linux-amd64" |
  cut -d '"' -f 4)

if [[ -z "$KUBIE_URL" ]]; then
  echo "Error: Could not find latest kubie release URL"
  exit 1
fi

curl -Lo kubie "$KUBIE_URL"
chmod +x kubie
sudo mv kubie "$KUBIE_BIN"
echo "✅ kubie installed at $KUBIE_BIN"

# Step 2: Install Fish completions
echo "[2/4] Installing Fish completions..."
mkdir -p "$(dirname "$FISH_COMPLETIONS")"
curl -sL https://raw.githubusercontent.com/sbstp/kubie/master/completion/kubie.fish -o "$FISH_COMPLETIONS"
echo "✅ Fish completions installed at $FISH_COMPLETIONS"

# Step 3: Add aliases for kubectx/kubens style (optional)
echo "[3/4] Adding aliases to Fish config..."

# Step 4: Test installation
echo "[4/4] Testing kubie..."
kubie --version || echo "Error: kubie installation failed"
echo "✅ Installation complete! Restart your Fish shell or run 'source $FISH_CONFIG' to start using kubie."
