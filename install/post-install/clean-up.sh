#!/usr/bin/env bash

# Remove unwanted groups
mapfile -t groups < <(grep -v '^#' "$DESKTOP_INSTALL/desktop-removed.groups" | grep -v '^$')
sudo dnf group remove -y "${groups[@]}"

# Remove unwanted packages
mapfile -t packages < <(grep -v '^#' "$DESKTOP_INSTALL/desktop-removed.packages" | grep -v '^$')
sudo dnf remove -y "${packages[@]}"

# Remove NetworkManager configuration
sudo rm -rf /etc/NetworkManager
