#!/usr/bin/env bash

# Variables
APP_NAME="stack"
APP_URL="https://filehosting-client.transip.nl/packages/stack-linux-latest-x86_64.AppImage"
INSTALL_DIR="/opt/applications"
APP_PATH="$INSTALL_DIR/$APP_NAME.AppImage"
DESKTOP_DIR="$HOME/.local/share/applications"
DESKTOP_FILE="$DESKTOP_DIR/$APP_NAME.desktop"
ICON_URL="https://play-lh.googleusercontent.com/H-khu2uat9G8M_dfQto6TpunFgbcrEgQDyPNAOnrPUJnHSgpdvjmqHRtALbIzt2jtgA=w240-h480-rw"
ICON_FILE="$INSTALL_DIR/$APP_NAME.png"

# Create installation directories if they don't exist
mkdir -p "$INSTALL_DIR"
#mkdir -p "$DESKTOP_DIR"

# Download the AppImage
echo "Downloading $APP_NAME..."
curl -L -o "$APP_PATH" "$APP_URL"

# Make it executable
chmod +x "$APP_PATH"

# Add to PATH if not already
# if ! echo "$PATH" | grep -q "$INSTALL_DIR"; then
#     echo "Adding $INSTALL_DIR to PATH..."
#     SHELL_RC="$HOME/.bashrc"
#     if [ -n "$ZSH_VERSION" ]; then
#         SHELL_RC="$HOME/.zshrc"
#     fi
#     echo "export PATH=\"$INSTALL_DIR:\$PATH\"" >> "$SHELL_RC"
#     echo "PATH updated in $SHELL_RC. Reload your shell or run 'source $SHELL_RC'."
# fi
#
# # Download the icon
# echo "Downloading icon..."
# curl -L -o "$ICON_FILE" "$ICON_URL"
#
# # Create a desktop entry
# echo "Creating desktop entry..."
# cat > "$DESKTOP_FILE" <<EOL
# [Desktop Entry]
# Name=$APP_NAME
# Comment=Stack Client
# Exec=$APP_PATH
# Icon=$ICON_FILE
# Terminal=false
# Type=Application
# Categories=Utility;
# EOL
#
# # Make desktop entry executable
# chmod +x "$DESKTOP_FILE"
#
