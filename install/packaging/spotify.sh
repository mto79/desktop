#!/usr/bin/env bash

set -euo pipefail

echo "▶ Installing Flatpak (if needed)..."
sudo dnf install -y flatpak

echo "▶ Adding Flathub repository (if not already present)..."
sudo flatpak remote-add --if-not-exists flathub \
  https://dl.flathub.org/repo/flathub.flatpakrepo

echo "▶ Installing Spotify..."
flatpak install -y flathub com.spotify.Client

echo "✅ Spotify installed successfully!"
echo "▶ Run it with: flatpak run com.spotify.Client"
