#!/usr/bin/env bash

# desktop-security check every fifteen minutes, which notifies once for each new finding.
# The first run records the startup items and setuid programs it finds as the baseline.
systemctl --user enable --now desktop-security-check.timer
