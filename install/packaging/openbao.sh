#!/usr/bin/env bash
set -euo pipefail

# No repo needed: openbao is in the official Fedora repos (and EPEL).

echo "Installing OpenBao..."
sudo dnf install -y openbao

echo
echo "OpenBao installed:"
bao -version
