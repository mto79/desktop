#!/usr/bin/env bash

# https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli#install-terraform
# Exit immediately if a command exits with a non-zero status

echo "==> Detecting Fedora version..."
FEDORA_VERSION=$(grep -oP '\d+' /etc/fedora-release)
ARCH=$(uname -m)

echo "==> Detected Fedora $FEDORA_VERSION on $ARCH architecture"

# Add HashiCorp repo dynamically
sudo tee /etc/yum.repos.d/hashicorp.repo >/dev/null <<EOF
[hashicorp]
name=HashiCorp Stable - \$basearch
baseurl=https://rpm.releases.hashicorp.com/fedora/${FEDORA_VERSION}/$ARCH/stable
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
