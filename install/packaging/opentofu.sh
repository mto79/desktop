#!/usr/bin/env bash
set -euo pipefail

REPO_FILE="/etc/yum.repos.d/opentofu.repo"

# Upstream's snippet pins sslcacert to /etc/pki/tls/certs/ca-bundle.crt, which Fedora 44
# no longer ships -- ca-certificates moved the bundle to /etc/ssl/certs/ca-bundle.crt.
# Every fetch then dies inside curl with "problem with the SSL CA cert" while dnf still
# exits 0, so tofu quietly stops being upgradable and a clean install cannot find it at
# all. Dropping both ssl lines verifies against the system trust store, which is what
# that path pointed at anyway, and cannot be broken again by the bundle moving.
echo "Installing OpenTofu repository..."

sudo tee "$REPO_FILE" >/dev/null <<'EOF'
[opentofu]
name=OpenTofu
baseurl=https://packages.opentofu.org/opentofu/tofu/rpm_any/rpm_any/$basearch
repo_gpgcheck=0
gpgcheck=1
enabled=1
gpgkey=https://get.opentofu.org/opentofu.gpg
       https://packages.opentofu.org/opentofu/tofu/gpgkey
metadata_expire=300
EOF

echo "Installing OpenTofu..."

sudo dnf install -y tofu

echo
echo "OpenTofu installed:"
tofu version
