#!/usr/bin/env bash

# Kernel hardening on a machine installed before install/config/security.sh set it:
# ptrace limited to a process's own children, and kernel addresses hidden. See
# default/sysctl/90-desktop-hardening.conf for what each costs.

sudo install -m 0644 "$HOME/.local/share/desktop/default/sysctl/90-desktop-hardening.conf" /etc/sysctl.d/ || exit 1
sudo sysctl -q -p /etc/sysctl.d/90-desktop-hardening.conf
