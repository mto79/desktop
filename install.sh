#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -eEo pipefail

# Define paths
DESKTOP_PATH="$HOME/.local/share/desktop"
DESKTOP_INSTALL="$DESKTOP_PATH/install"
export PATH="$DESKTOP_PATH/bin:$PATH"

# Install
source "$DESKTOP_INSTALL/preflight/all.sh"
source "$DESKTOP_INSTALL/packaging/all.sh"
source "$DESKTOP_INSTALL/config/all.sh"
source "$DESKTOP_INSTALL/login/all.sh"
source "$DESKTOP_INSTALL/post-install/all.sh"

