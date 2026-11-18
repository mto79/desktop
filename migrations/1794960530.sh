#!/usr/bin/env bash

# A pointer at the login screen: SDDM is told which cursor theme to give its greeter, and a
# size the 3840x2400 panel shows. The install's own script, run again; it replaces the
# theme and its settings whole, so running it twice changes nothing more.

sudo dnf install -y adwaita-cursor-theme
source "$HOME/.local/share/desktop/install/login/sddm.sh"
echo "  the login screen has a pointer again, from the next login"
