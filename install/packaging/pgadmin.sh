#!/usr/bin/env bash
set -euo pipefail

# pgAdmin 4 (desktop) installer for Fedora 43

REPO_RPM="https://ftp.postgresql.org/pub/pgadmin/pgadmin4/yum/pgadmin4-fedora-repo-2-1.noarch.rpm"

echo "==> Checking for sudo access..."
sudo -v

echo "==> Installing pgAdmin 4 repository..."
if rpm -q pgadmin4-fedora-repo >/dev/null 2>&1; then
  echo "    Repository already installed, skipping."
else
  sudo rpm -i "${REPO_RPM}"
fi

echo "==> Refreshing metadata..."
sudo dnf makecache

echo "==> Installing pgadmin4-desktop..."
sudo dnf install -y pgadmin4-desktop

echo "==> Installation complete!"
echo "    You can start pgAdmin with: pgadmin4"
