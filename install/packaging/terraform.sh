#!/usr/bin/env bash
set -e

# https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli#install-terraform
# Exit immediately if a command exits with a non-zero status

echo "==> Detecting Fedora version..."
FEDORA_VERSION=$(grep -oP '\d+' /etc/fedora-release)
ARCH=$(uname -m)

echo "==> Detected Fedora $FEDORA_VERSION on $ARCH architecture"

# Determine equivalent RHEL version for repo
if [ "$FEDORA_VERSION" -ge 35 ]; then
  RHEL_VERSION=9
else
  RHEL_VERSION=8
fi

# Add HashiCorp repo dynamically
sudo tee /etc/yum.repos.d/hashicorp.repo >/dev/null <<EOF
[hashicorp]
name=HashiCorp Stable - \$basearch
baseurl=https://rpm.releases.hashicorp.com/RHEL/${RHEL_VERSION}/$ARCH/stable
enabled=1
gpgcheck=1
gpgkey=https://rpm.releases.hashicorp.com/gpg
EOF

echo "==> Installing Terraform..."
sudo dnf -y install terraform

# Verify installation
echo "==> Terraform installed:"
terraform -version

echo "Terraform installation complete!"
