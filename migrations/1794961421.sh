#!/usr/bin/env bash

# The boot menu's sizes again: half the panel was not a size this laptop's firmware offers,
# and GRUB fell back to the full resolution. More sizes to try before that one.
source "$HOME/.local/share/desktop/install/config/hardware/grub-hidpi.sh"
echo "  the boot menu tries 1920x1200, 1280x800 and 1024x768 before the panel's own size"
