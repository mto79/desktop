#!/usr/bin/env bash

# Give the machine something that kills a runaway before it takes the desktop with it.
#
# A terminal running a loop against a cluster grew to 54.9G of this machine's 62G, pushed
# 6.7G into zram, and froze everything for good. Nothing was killed and nothing was
# logged: the kernel's OOM killer waits for an allocation to fail, and a thrashing machine
# never quite gets there -- it reclaims instead, and starves the compositor of memory and
# CPU while it does. systemd-oomd watches pressure rather than failure, and was disabled
# here, with the policy package that tells it what to watch not installed at all.
#
# Also asks that Hyprland be the last cgroup it picks. See install/config/oom.sh.

if ! rpm -q systemd-oomd-defaults >/dev/null 2>&1; then
  # --disablerepo because pgAdmin4's repo fails GPG verification, and one bad repo stops
  # a transaction that has nothing to do with it.
  sudo dnf install -y --disablerepo=pgAdmin4 systemd-oomd-defaults || exit 1
  echo "  installed the pressure policy for every user slice"
fi

if [[ $(systemctl is-active systemd-oomd.service) != active ]]; then
  sudo systemctl enable --now systemd-oomd.service || exit 1
  echo "  systemd-oomd is now watching memory pressure"
else
  sudo systemctl enable systemd-oomd.service >/dev/null 2>&1
  echo "  systemd-oomd was already running"
fi

# config/ is copied into ~/.config only by the installer, so the drop-in is placed here.
DROPIN="$HOME/.local/share/desktop/config/systemd/user/wayland-wm@.service.d/10-oom-avoid.conf"
DEST="$HOME/.config/systemd/user/wayland-wm@.service.d/10-oom-avoid.conf"
if ! cmp -s "$DROPIN" "$DEST"; then
  mkdir -p "$(dirname "$DEST")"
  install -m 0644 "$DROPIN" "$DEST" || exit 1
  systemctl --user daemon-reload
  # daemon-reload is enough: systemd sets the xattr oomd reads on the running cgroup, so
  # the compositor is protected without logging out.
  echo "  Hyprland now asks systemd-oomd to kill it last"
fi
