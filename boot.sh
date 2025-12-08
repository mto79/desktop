#!/usr/bin/env bash

# Set install mode to online since boot.sh is used for curl installations
export DESKTOP_ONLINE_INSTALL=true

clear

# Install git
sudo dnf install -y git

# Use custom repo if specified, otherwise default
DESKTOP_REPO="${DESKTOP_REPO:-mto79/desktop}"

echo -e "\nCloning from: https://github.com/${DESKTOP_REPO}.git"
rm -rf ~/.local/share/desktop/
git clone "https://github.com/${DESKTOP_REPO}.git" ~/.local/share/desktop >/dev/null

# Use custom branch if instructed, otherwise default to main
DESKTOP_REF="${REF:-develop}"
if [[ $REF != "main" ]]; then
  echo -e "\eUsing branch: $REF"
  cd ~/.local/share/desktop
  git fetch origin "${DESKTOP_REF}" && git checkout "${DESKTOP_REF}"
  cd -
fi

echo -e "\nInstallation starting..."
source ~/.local/share/desktop/install.sh
