#!/usr/bin/env bash

# A readable boot menu on a HiDPI laptop panel: GRUB draws at half the panel's resolution.
#
# GRUB draws its menu pixel for pixel. At a 3840x2400 panel's own resolution even a 32-pixel
# font is small, and with Secure Boot on it is smaller still: the menu came up in GRUB's
# tiny fallback font, though grub.cfg loads a DejaVu one that is there -- nothing changed
# but Secure Boot. Halving the resolution doubles every character whatever font GRUB ends
# up with, and the panel scales the picture up. "auto" is what GRUB falls back to should
# the firmware offer none of them.
#
# Only for a panel wider than 2560: anything smaller reads well enough at its own size.
grub_hidpi_mode() {
  local mode
  mode=$(cat /sys/class/drm/card*-eDP-*/modes 2>/dev/null | head -1)
  [[ $mode =~ ^([0-9]+)x([0-9]+)$ ]] || return 1
  ((BASH_REMATCH[1] > 2560)) || return 1
  # GRUB takes the first the firmware offers. Half the panel came first, and was not one: this
  # laptop's firmware has no 1920x1200, and "auto" was the full 3840x2400 again. 1280x800 keeps
  # 16:10; 1024x768, which nearly every firmware has, may stretch a little but is legible.
  echo "$((BASH_REMATCH[1] / 2))x$((BASH_REMATCH[2] / 2)),1280x800,1024x768,auto"
}

if GRUB_HIDPI_MODE=$(grub_hidpi_mode) && [[ -f /etc/default/grub ]]; then
  if grep -q '^GRUB_GFXMODE=' /etc/default/grub; then
    sudo sed -i "s|^GRUB_GFXMODE=.*|GRUB_GFXMODE=\"$GRUB_HIDPI_MODE\"|" /etc/default/grub
  else
    echo "GRUB_GFXMODE=\"$GRUB_HIDPI_MODE\"" | sudo tee -a /etc/default/grub >/dev/null
  fi
  grep -q '^GRUB_TERMINAL_OUTPUT=' /etc/default/grub ||
    echo 'GRUB_TERMINAL_OUTPUT="gfxterm"' | sudo tee -a /etc/default/grub >/dev/null
  # Fedora's grub.cfg on the EFI partition only points at this one.
  sudo grub2-mkconfig -o /boot/grub2/grub.cfg >/dev/null
fi
