#!/usr/bin/env bash

set -euo pipefail

REPO_URL="https://github.com/jonathanio/update-systemd-resolved.git"
SCRIPT_NAME="update-systemd-resolved"
DEST_DIR="/etc/openvpn/scripts"
DEST_PATH="${DEST_DIR}/${SCRIPT_NAME}"

# Ensure required commands exist
for cmd in git sudo install mktemp; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "Error: required command '$cmd' not found" >&2
    exit 1
  }
done

# Create temp working directory
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# Clone repository
git clone --depth 1 "$REPO_URL" "$TMP_DIR"

# Install script with correct permissions
sudo install -Dm755 "$TMP_DIR/$SCRIPT_NAME" "$DEST_PATH"

echo "Installed $SCRIPT_NAME to $DEST_PATH"
