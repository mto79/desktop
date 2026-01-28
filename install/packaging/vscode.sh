#!/usr/bin/env bash

# Installs official VS Code with repo setup

set -e

echo "Importing Microsoft GPG key..."
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc

echo "Adding VS Code repository..."
sudo sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'

#echo "Updating package cache..."
#sudo dnf check-update

echo "Installing VS Code..."
sudo dnf install -y code

echo "VS Code installation complete!"
echo "You can launch VS Code with: code"
