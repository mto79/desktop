#!/usr/bin/env bash

# https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli#install-terraform
# Exit immediately if a command exits with a non-zero status

echo "Adding HashiCorp repository..."
sudo dnf install -y 'dnf-command(config-manager)'

sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/fedora/hashicorp.repo

echo "Installing Terraform..."
sudo dnf install -y terraform

echo "Verifying Terraform installation..."
terraform -version

echo "Terraform installation complete!"
