#!/usr/bin/env bash

# Variables
THEME_NAME="tokyo-night-sddm"
TEMP_DIR="/tmp/$THEME_NAME"
SDDM_GIT_URL="https://github.com/mto79/desktop_sddm.git"
SDDM_THEME_DIR="/usr/share/sddm/themes"

# Clone the repo to a temporary directory -- afresh, so a copy left by an earlier run
# does not make the clone fail.
echo "Cloning SDDM theme..."
rm -rf "$TEMP_DIR"
git clone --depth 1 "$SDDM_GIT_URL" "$TEMP_DIR"

# Copy the theme to SDDM themes directory, replacing what was there rather than copying
# over it: a file the theme dropped -- the old background -- would otherwise stay. Its git
# history is no part of the theme.
echo "Installing theme to $SDDM_THEME_DIR..."
sudo rm -rf "${SDDM_THEME_DIR:?}/$THEME_NAME"
sudo mkdir -p "$SDDM_THEME_DIR/$THEME_NAME"
sudo cp -r "$TEMP_DIR/." "$SDDM_THEME_DIR/$THEME_NAME/"
sudo rm -rf "$SDDM_THEME_DIR/$THEME_NAME/.git"

# Create SDDM config directory if it doesn't exist
sudo mkdir -p /etc/sddm.conf.d

# Set sddm theme -- and the pointer, named and sized for the panel: the login screen showed
# none. Left to itself the greeter, running as sddm, was given no cursor theme, and at
# 3840x2400 a 24-pixel pointer is a speck besides. Twice that on a panel wider than 2560.
echo "Setting the default SDDM theme..."
CURSOR_SIZE=24
[[ $(cat /sys/class/drm/card*-eDP-*/modes 2>/dev/null | head -1) =~ ^([0-9]+)x ]] &&
  ((BASH_REMATCH[1] > 2560)) && CURSOR_SIZE=48
sudo tee /etc/sddm.conf.d/theme.conf >/dev/null <<EOF
[Theme]
Current=$THEME_NAME
CursorTheme=Adwaita
CursorSize=$CURSOR_SIZE
EOF

# Tap-to-click at the login screen: SDDM draws it in Weston, which leaves a touchpad's
# taps off where Hyprland turns them on. See default/sddm/weston.ini.
sudo install -D -m 0644 "$DESKTOP_PATH/default/sddm/weston.ini" /etc/sddm/weston.ini
sudo install -D -m 0644 "$DESKTOP_PATH/default/sddm/weston.conf" /etc/sddm.conf.d/weston.conf

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
