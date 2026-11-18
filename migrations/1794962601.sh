#!/usr/bin/env bash

# The boot menu's size set where GRUB keeps it under Secure Boot too: after the "if the font
# loaded" block that skipped it, by /etc/grub.d/01_desktop-gfxmode. The install's own script.
source "$HOME/.local/share/desktop/install/config/hardware/grub-hidpi.sh"
echo "  the boot menu is drawn at a size the panel can be read at, from the next boot"
