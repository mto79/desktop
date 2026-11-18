#!/usr/bin/env bash

# A readable boot menu on a HiDPI laptop panel: GRUB draws at half the panel's resolution.
#
# GRUB draws its menu pixel for pixel. At a 3840x2400 panel's own resolution even a 32-pixel
# font is small, and with Secure Boot on it is smaller still: the menu came up in GRUB's
# tiny fallback font, though grub.cfg loads a DejaVu one that is there -- nothing changed
# but Secure Boot. Halving the resolution doubles every character whatever font GRUB ends
# up with, and the panel scales the picture up. "auto" is what GRUB falls back to should
# the firmware not offer the half size.
#
# Only for a panel wider than 2560: anything smaller reads well enough at its own size.
grub_hidpi_mode() {
  local mode
  mode=$(cat /sys/class/drm/card*-eDP-*/modes 2>/dev/null | head -1)
  [[ $mode =~ ^([0-9]+)x([0-9]+)$ ]] || return 1
  ((BASH_REMATCH[1] > 2560)) || return 1
  echo "$((BASH_REMATCH[1] / 2))x$((BASH_REMATCH[2] / 2)),auto"
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
  sudo grub2-mkconfig -o /boot/grub2/grub.cfg >/dev/null 2>&1
fi
