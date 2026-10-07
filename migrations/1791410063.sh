#!/usr/bin/env bash

# Install the Red Hat Training Lab Connector on a machine that was set up before it was in
# the package list.
#
# rhtlc is how the online lab environments of Red Hat's courses are reached from a real
# desktop instead of a browser tab: SSH, SFTP, a SOCKS proxy and a VPN through one
# WebSockets tunnel, with a GUI and an rhtlc:// handler the course pages link to. It is
# not in Fedora; the course documentation's own source for RPM systems is a COPR, which
# means dnf keeps it current like anything else. A clean install enables that COPR in
# install/preflight/copr.sh and takes the package from desktop-base.packages.

if ! dnf repolist --enabled 2>/dev/null | grep -qi 'tmichett:RHTLC'; then
  sudo dnf copr enable -y tmichett/RHTLC || exit 1
  echo "  enabled the tmichett/RHTLC copr"
fi

if ! rpm -q rhtlc >/dev/null 2>&1; then
  # --disablerepo because pgAdmin4's repo fails GPG verification, and one bad repo stops
  # a transaction that has nothing to do with it.
  sudo dnf install -y --disablerepo=pgAdmin4 rhtlc || exit 1
  echo "  installed rhtlc $(rpm -q --qf '%{VERSION}' rhtlc)"
else
  echo "  rhtlc was already installed"
fi
