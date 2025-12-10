#!/usr/bin/env bash

# Variables
THEME_NAME="tokyo-night-sddm"
TEMP_DIR="/tmp/$THEME_NAME"
SDDM_GIT_URL="https://github.com/mto79/desktop_sddm.git"
SDDM_THEME_DIR="/usr/share/sddm/themes"

# Clone the repo to a temporary directory
echo "Cloning SDDM theme..."
git clone --depth 1 "$SDDM_GIT_URL" "$TEMP_DIR"

# Copy the theme to SDDM themes directory
echo "Installing theme to /usr/share/sddm/themes..."
sudo mkdir -p "/usr/share/sddm/themes/$THEME_NAME"
sudo cp -r "$TEMP_DIR/." "/usr/share/sddm/themes/$THEME_NAME/"

# Create SDDM config directory if it doesn't exist
sudo mkdir -p /etc/sddm.conf.d

# Set sddm theme
echo "Setting the default SDDM theme..."
sudo tee /etc/sddm.conf.d/theme.conf >/dev/null <<EOF
[Theme]
Current=$THEME_NAME
EOF

# Clean up temporary files
echo "Cleaning up..."
rm -rf "$TEMP_DIR"

# Set sddm autologin
# if [ ! -f /etc/sddm.conf.d/autologin.conf ]; then
#  cat <<EOF | sudo tee /etc/sddm.conf.d/autologin.conf
# [Autologin]
# User=$USER
# Session=hyprland-uwsm
# EOF
# fi

# Don't use chrootable here as --now will cause issues for manual installs
sudo systemctl enable sddm.service
