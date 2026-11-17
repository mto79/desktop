#!/usr/bin/env bash

# The login screen fitted to the screen it is on, in the desktop's colours and font. The
# theme comes from its own repository, so it is installed again from there; its font has
# to be installed for every user, since the login screen runs as sddm and reads no one's
# home.

sudo dnf install -y jetbrains-mono-fonts
source "$HOME/.local/share/desktop/install/login/sddm.sh"
echo "  the login screen is in the desktop's look; it shows at the next login"
