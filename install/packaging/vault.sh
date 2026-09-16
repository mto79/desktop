#!/usr/bin/env bash
set -euo pipefail

REPO_FILE="/etc/yum.repos.d/hashicorp.repo"

# Written out rather than piped from the web: a failed transfer would otherwise leave
# a truncated repo file behind, and dnf would fail on the next run without saying why.
echo "Installing HashiCorp repository..."
sudo tee "$REPO_FILE" >/dev/null <<'EOF'
[hashicorp]
name=Hashicorp Stable - $basearch
baseurl=https://rpm.releases.hashicorp.com/fedora/$releasever/$basearch/stable
enabled=1
gpgcheck=1
gpgkey=https://rpm.releases.hashicorp.com/gpg

[hashicorp-test]
name=Hashicorp Test - $basearch
baseurl=https://rpm.releases.hashicorp.com/fedora/$releasever/$basearch/test
enabled=0
gpgcheck=1
gpgkey=https://rpm.releases.hashicorp.com/gpg
EOF

echo "Installing Vault..."
sudo dnf install -y vault

echo
echo "Vault installed:"
vault -version
