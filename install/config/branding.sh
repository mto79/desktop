#!/usr/bin/env bash

# Allow the user to change the branding for fastfetch and screensaver
mkdir -p ~/.config/desktop/branding
cp ~/.local/share/desktop/icon.txt ~/.config/desktop/branding/about.txt
cp ~/.local/share/desktop/logo.txt ~/.config/desktop/branding/screensaver.txt
