#!/usr/bin/env bash

# The laptop's screen flickers while the bar's orb or the line along the clock moves:
# PSR2 selective fetch on the Intel panel mishandles a small region redrawn many times a
# second. install/config/hardware/intel-psr.sh turns selective fetch off on a fresh
# install; this is for the machine that already exists. It needs a reboot to take effect.

if grep -q 'i915.enable_psr2_sel_fetch=0' /proc/cmdline; then
  echo "  selective fetch is already off"
else
  source ~/.local/share/desktop/install/config/hardware/intel-psr.sh || exit 1
  echo "  selective fetch is off from the next boot, if this machine has an Intel panel"
fi
