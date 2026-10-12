#!/usr/bin/env bash

# Stop the laptop's own screen flickering while something small on it keeps moving.
#
# An Intel panel that supports PSR2 is sent only the part of the frame that changed
# ("selective fetch"). On this machine's Meteor Lake that goes wrong when the changed part
# is a small region redrawn many times a second: the whole panel flickers. Nothing did
# that until the bar got an orb that animates while an agent works and a line that runs
# along the clock, and then the laptop's screen flickered whenever either moved -- the
# external monitors, which have no PSR, never did. Repainting whole frames
# (debug:damage_tracking 0) made it stop, which is what pinned it on the partial updates.
#
# Without selective fetch the driver falls back to PSR1, which still lets the panel
# refresh itself while nothing changes, so an idle screen costs what it did before.
intel_psr_panel() {
  local panel
  for panel in /sys/class/drm/card*-eDP-*; do
    [[ $(basename "$(readlink -f "$panel/device/device/driver" 2>/dev/null)") == i915 ]] && return 0
  done
  return 1
}

if intel_psr_panel; then
  PSR_ARG="i915.enable_psr2_sel_fetch=0"

  # grubby covers the kernels already installed; /etc/default/grub is what every future
  # one inherits. Takes effect at the next boot.
  grep -q -- "$PSR_ARG" /etc/default/grub || sudo sed -i "s|^GRUB_CMDLINE_LINUX=\"|GRUB_CMDLINE_LINUX=\"$PSR_ARG |" /etc/default/grub
  sudo grubby --update-kernel=ALL --args="$PSR_ARG"
fi
