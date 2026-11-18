#!/usr/bin/env bash

# A readable boot menu on a HiDPI laptop panel: GRUB draws at a smaller resolution.
#
# GRUB draws its menu pixel for pixel, so at a 3840x2400 panel's own resolution its text is
# small. With Secure Boot on it is tiny: the font grub.cfg loads is passed over, and GRUB
# falls back to one of its own. Drawing at a lower resolution makes every character bigger,
# whatever font GRUB ends up with, and the panel scales the picture up.
#
# GRUB_GFXMODE alone does not do it. Fedora's 00_header writes the size, the video drivers
# and the graphical terminal inside "if loadfont ...; then" -- a font that does not load
# skips the size with it, and the menu stays at the panel's own resolution. This was
# GRUB_GFXMODE twice over, with no change on screen. So the size is set again after that
# block, by a script of its own in /etc/grub.d, whether the font loaded or not, and the
# graphical terminal is started again so that it takes it.
#
# Only for a panel wider than 2560: anything smaller reads well enough at its own size.
grub_hidpi_mode() {
  local mode
  mode=$(cat /sys/class/drm/card*-eDP-*/modes 2>/dev/null | head -1)
  [[ $mode =~ ^([0-9]+)x([0-9]+)$ ]] || return 1
  ((BASH_REMATCH[1] > 2560)) || return 1
  # GRUB takes the first the firmware offers: half the panel, 1280x800 to keep 16:10, and
  # 1024x768, which nearly every firmware has; "auto" when it offers none of them.
  echo "$((BASH_REMATCH[1] / 2))x$((BASH_REMATCH[2] / 2)),1280x800,1024x768,auto"
}

# What /etc/grub.d/01_desktop-gfxmode prints into grub.cfg, right after 00_header.
grub_hidpi_script() { # mode
  printf '%s\n' \
    '#!/bin/sh' \
    '# Written by the desktop (install/config/hardware/grub-hidpi.sh): the boot menu at a' \
    '# size a HiDPI panel can be read at, set whether or not 00_header'"'"'s font loaded.' \
    'cat <<GRUB' \
    "set gfxmode=$1" \
    'load_video' \
    'insmod gfxterm' \
    'terminal_output console' \
    'terminal_output gfxterm' \
    'GRUB'
}

if GRUB_HIDPI_MODE=$(grub_hidpi_mode) && [[ -f /etc/default/grub ]]; then
  if grep -q '^GRUB_GFXMODE=' /etc/default/grub; then
    sudo sed -i "s|^GRUB_GFXMODE=.*|GRUB_GFXMODE=\"$GRUB_HIDPI_MODE\"|" /etc/default/grub
  else
    echo "GRUB_GFXMODE=\"$GRUB_HIDPI_MODE\"" | sudo tee -a /etc/default/grub >/dev/null
  fi
  grep -q '^GRUB_TERMINAL_OUTPUT=' /etc/default/grub ||
    echo 'GRUB_TERMINAL_OUTPUT="gfxterm"' | sudo tee -a /etc/default/grub >/dev/null
  grub_hidpi_script "$GRUB_HIDPI_MODE" | sudo tee /etc/grub.d/01_desktop-gfxmode >/dev/null
  sudo chmod 0755 /etc/grub.d/01_desktop-gfxmode
  # Fedora's grub.cfg on the EFI partition only points at this one.
  sudo grub2-mkconfig -o /boot/grub2/grub.cfg >/dev/null
fi
