#!/usr/bin/env bash

# The boot menu at half a HiDPI panel's resolution, so it can be read with Secure Boot on.
# The install's own script; on a panel 2560 wide or less it does nothing.
source "$HOME/.local/share/desktop/install/config/hardware/grub-hidpi.sh"
echo "  the boot menu is drawn at half the panel's resolution, from the next boot"
