#!/usr/bin/env bash

# desktop-security check every fifteen minutes, which notifies once for each new finding.
# The first run records the startup items and setuid programs it finds as the baseline.
systemctl --user enable --now desktop-security-check.timer

# The check reads which ports each firewall zone admits, which firewalld otherwise asks an
# admin password for -- a fingerprint prompt every fifteen minutes. Reading only.
sudo install -m 0644 "$DESKTOP_PATH/default/polkit/49-desktop-firewall-read.rules" /etc/polkit-1/rules.d/

# No program of yours reading another's memory, and no kernel addresses for the asking.
# What each setting costs is in the file. Applied now as well as at the next boot.
sudo install -m 0644 "$DESKTOP_PATH/default/sysctl/90-desktop-hardening.conf" /etc/sysctl.d/
sudo sysctl -q -p /etc/sysctl.d/90-desktop-hardening.conf

# No SSH logins to a laptop nobody logs in to remotely. sshd listens on every interface the
# machine has, the VPN's included, and Fedora's default firewall zone admits it, so unused
# it is only a way in. Off, with the socket unit that would start it again on the first
# connection, and the firewall's ssh service removed so that sshd coming back by accident
# does not also bring back a port that answers. See the migration that did this for a
# machine already installed for how to turn it on again.
sudo systemctl disable --now sshd.service sshd.socket 2>/dev/null || true
if command -v firewall-cmd >/dev/null 2>&1 && sudo firewall-cmd --state >/dev/null 2>&1; then
  for zone in $(sudo firewall-cmd --permanent --get-zones 2>/dev/null); do
    sudo firewall-cmd --permanent --zone="$zone" --remove-service=ssh >/dev/null 2>&1 || true
  done
  sudo firewall-cmd --reload >/dev/null 2>&1 || true
fi
