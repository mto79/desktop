#!/usr/bin/env bash

# A bluetoothd that crashes should come back.
#
# Fedora ships bluetooth.service with Restart=on-failure commented out, so a segfault
# leaves the machine without Bluetooth until someone starts it by hand -- and without
# saying so: the headset just drops, and bluetoothctl hangs waiting for a daemon that is
# not there. It happened when Teams opened the camera: libcamera failed an assertion
# inside WirePlumber, WirePlumber aborted and took its A2DP endpoints with it, and
# bluez 5.87 segfaulted removing them. Neither bug is ours to fix; staying down is.
#
# systemd's own start limit -- five starts in ten seconds -- still stops a daemon that
# cannot stay up from being restarted for ever.
DROPIN_DIR="${DESKTOP_SYSTEMD_SYSTEM_PATH:-/etc/systemd/system}/bluetooth.service.d"
DROPIN="$DROPIN_DIR/10-restart.conf"

read -r -d '' WANTED <<'CONF' || true
[Service]
Restart=on-failure
RestartSec=2
CONF

# No bluez, no unit to restart: a machine without a radio is left alone.
if systemctl cat bluetooth.service &>/dev/null && [[ "$(cat "$DROPIN" 2>/dev/null)" != "$WANTED" ]]; then
  sudo install -d -m 0755 "$DROPIN_DIR"
  printf '%s\n' "$WANTED" | sudo tee "$DROPIN" >/dev/null
  sudo systemctl daemon-reload
  echo "  bluetoothd is restarted when it crashes"
fi
