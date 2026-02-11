#!/usr/bin/env bash

set -euo pipefail

echo "▶ Installing Flatpak (if needed)..."
sudo dnf install -y flatpak

echo "▶ Adding Flathub repository (if not already present)..."
sudo flatpak remote-add --if-not-exists flathub \
  https://dl.flathub.org/repo/flathub.flatpakrepo

echo "▶ Installing Podman Desktop..."
flatpak install flathub io.podman_desktop.PodmanDesktop

echo "✅ Podman installed successfully!"
echo "▶ Run it with: flatpak run io.podman_desktop.PodmanDesktop"
