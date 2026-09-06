#!/usr/bin/env bash

ICON_DIR="$HOME/.local/share/applications/icons"

# Must run after icons are installed
desktop-tui-install "Disk Usage" "desktop-gdu /" float "$ICON_DIR/Disk Usage.png"
