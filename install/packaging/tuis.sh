#!/usr/bin/env bash

ICON_DIR="$HOME/.local/share/applications/icons"

# Must run after icons are installed
desktop-tui-install "Disk Usage" "bash -c 'dust -r; read -n 1 -s'" float "$ICON_DIR/Disk Usage.png"
