#!/usr/bin/env bash

# Brave Browser installer for Fedora 43

echo "==> Installing Brave Browser.."

# Create Brave repo file
sudo tee /etc/yum.repos.d/brave-browser.repo >/dev/null <<'EOF'
[brave-browser]
name=Brave Browser
baseurl=https://brave-browser-rpm-release.s3.brave.com/x86_64/
enabled=1
gpgcheck=1
gpgkey=https://brave-browser-rpm-release.s3.brave.com/brave-core.asc
EOF

echo "==> Importing Brave GPG key..."
sudo rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc

echo "==> Installing Brave Browser..."
sudo dnf install -y brave-browser

echo "==> Brave Browser installation complete!"
