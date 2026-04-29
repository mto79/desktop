#!/usr/bin/env bash

set -euo pipefail

echo "▶ Installing WireGuard tools..."
sudo dnf install -y wireguard-tools

echo "▶ Loading WireGuard kernel module..."
sudo modprobe wireguard

echo "▶ Ensuring WireGuard module loads on boot..."
echo "wireguard" | sudo tee /etc/modules-load.d/wireguard.conf > /dev/null

echo "▶ Restarting NetworkManager..."
sudo systemctl restart NetworkManager

echo "✅ WireGuard installed successfully!"
echo "▶ Import a config with: nmcli connection import type wireguard file <config.conf>"
echo "▶ Or use nm-connection-editor / Settings → VPN to add a WireGuard connection."
