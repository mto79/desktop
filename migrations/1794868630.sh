#!/usr/bin/env bash

# nvidia-settings' autostart restores X server settings, and there is no X server: it
# failed at every login. A user entry of the same name with Hidden=true turns it off.
mkdir -p ~/.config/autostart
cp ~/.local/share/desktop/config/autostart/nvidia-settings-load.desktop ~/.config/autostart/
