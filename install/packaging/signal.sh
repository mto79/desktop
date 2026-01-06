#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://download.opensuse.org/repositories/network:im:signal/Fedora_43/network:im:signal.repo"
REPO_NAME="network:im:signal"

echo "==> Checking for sudo access..."
sudo -v

echo "==> Adding Signal repository (${REPO_NAME})..."
if sudo dnf repolist | grep -q "${REPO_NAME}"; then
  echo "    Repository already exists, skipping."
else
  sudo dnf config-manager addrepo --from-repofile="${REPO_URL}"
fi

echo "==> Refreshing metadata..."
sudo dnf makecache

echo "==> Installing signal-desktop..."
sudo dnf install -y signal-desktop

echo "==> Installation complete!"
echo "    You can start Signal with: signal-desktop"
