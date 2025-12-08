#!/usr/bin/env bash

xdg-user-dirs-update

# Copy over configs
mkdir -p ~/.config
cp -R ~/.local/share/desktop/config/* ~/.config/

# Use default bashrc
cp ~/.local/share/desktop/default/bashrc ~/.bashrc
