#!/usr/bin/env bash

# Stop this machine accepting SSH logins.
#
# sshd was enabled and listening on every interface -- Wi-Fi, the dock's ethernet and the
# VPN tunnel alike -- on a laptop nobody logs in to remotely. The firewall admitted it too:
# Fedora's default zone allows ssh out of the box. A service that is not used is only ever
# a way in, and this one is the way in that gets guessed at from every network the laptop
# joins.
#
# Stopped, disabled, and the firewall's ssh service removed as well, so that a package
# update or a stray `systemctl start` that brings sshd back does not also bring back a
# port that answers. The socket unit goes too: enabled, it would start sshd again on the
# first connection.
#
# To log in to this machine over SSH again:
#   sudo systemctl enable --now sshd && sudo firewall-cmd --permanent --add-service=ssh && sudo firewall-cmd --reload

changed=false

for unit in sshd.service sshd.socket; do
  if systemctl is-enabled --quiet "$unit" 2>/dev/null || systemctl is-active --quiet "$unit" 2>/dev/null; then
    sudo systemctl disable --now "$unit" || exit 1
    echo "  $unit stopped and disabled"
    changed=true
  fi
done

if command -v firewall-cmd >/dev/null 2>&1 && sudo firewall-cmd --state >/dev/null 2>&1; then
  # Every zone that allows it, not only the one in use today: an interface that lands in
  # "home" or "work" tomorrow would otherwise be the one that still answers.
  for zone in $(sudo firewall-cmd --permanent --get-zones 2>/dev/null); do
    if sudo firewall-cmd --permanent --zone="$zone" --query-service=ssh >/dev/null 2>&1; then
      sudo firewall-cmd --permanent --zone="$zone" --remove-service=ssh >/dev/null || exit 1
      echo "  the firewall no longer admits ssh in zone $zone"
      changed=true
    fi
  done
  $changed && sudo firewall-cmd --reload >/dev/null
fi

$changed || echo "  sshd was already off and the firewall closed to it"
exit 0
