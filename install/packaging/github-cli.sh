#!/usr/bin/env bash

echo "Downloading and installing Github CLI..."

echo "Install dnf5-plugins"
sudo dnf install dnf5-plugins -y

echo "Add Github CLI repo"
sudo dnf config-manager addrepo --from-repofile=https://cli.github.com/packages/rpm/gh-cli.repo --overwrite

echo "Install using Github CLI with dnf5"
sudo dnf install gh --repo gh-cli -y

echo "Verifying glab installation..."
gh --version

echo "Github CLI installation complete!"
