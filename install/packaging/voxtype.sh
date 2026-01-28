#!/usr/bin/env bash

#!/usr/bin/env bash
set -euo pipefail

VOXTYPE_VERSION="0.4.1-4"
VOXTYPE_RPM="voxtype-${VOXTYPE_VERSION}.x86_64.rpm"
VOXTYPE_URL="https://github.com/peteonrails/voxtype/releases/download/v${VOXTYPE_VERSION}/${VOXTYPE_RPM}"

echo "▶ Checking Fedora version..."
FEDORA_VERSION=$(rpm -E %fedora)
if ((FEDORA_VERSION < 39)); then
  echo "❌ Fedora ${FEDORA_VERSION} is not supported (need Fedora 39+)"
  exit 1
fi

echo "▶ Installing optional dependencies..."
sudo dnf install -y wtype wl-clipboard ydotool

sudo systemctl enable ydotool.service
sudo systemctl start ydotool.service

sudo usermod -aG input $USER

# echo "▶ Checking if voxtype is already installed..."
# if rpm -q voxtype &>/dev/null; then
#   echo "✅ voxtype is already installed"
# fi
#
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

echo "▶ Downloading voxtype ${VOXTYPE_VERSION}..."
curl -fL "$VOXTYPE_URL" -o "$TMPDIR/$VOXTYPE_RPM"

echo "▶ Installing voxtype..."
sudo dnf install -y "$TMPDIR/$VOXTYPE_RPM"

echo "✅ voxtype installed successfully"

# Download whisper model and configure
voxtype setup --download
# Install as systemd service
voxtype setup systemd
