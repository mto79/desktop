#!/usr/bin/env bash

# Install base groups
mapfile -t groups < <(grep -v '^#' "$DESKTOP_INSTALL/desktop-base.groups" | grep -v '^$')
sudo dnf group install -y "${groups[@]}"

# Install base packages
mapfile -t packages < <(grep -v '^#' "$DESKTOP_INSTALL/desktop-base.packages" | grep -v '^$')
sudo dnf install -y "${packages[@]}"
