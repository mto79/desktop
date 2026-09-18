#!/usr/bin/env bash

# desktop-security check every fifteen minutes, which notifies once for each new finding.
# The first run records the startup items and setuid programs it finds as the baseline.
systemctl --user enable --now desktop-security-check.timer

# The check reads which ports each firewall zone admits, which firewalld otherwise asks an
# admin password for -- a fingerprint prompt every fifteen minutes. Reading only.
sudo install -m 0644 "$DESKTOP_PATH/default/polkit/49-desktop-firewall-read.rules" /etc/polkit-1/rules.d/
