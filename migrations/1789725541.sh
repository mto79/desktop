#!/usr/bin/env bash

# tshark for the network panel's traffic view, on machines installed before
# install/packaging/wireshark.sh existed. The panel works without it and says what is
# missing; this is what it asks for.

if rpm -q wireshark-cli >/dev/null 2>&1; then
  echo "  tshark is already installed"
else
  sudo dnf install -y wireshark-cli || exit 1
fi

if id -nG "$USER" | tr ' ' '\n' | grep -qx wireshark || getent group wireshark | grep -qw "$USER"; then
  echo "  $USER is already in the wireshark group"
else
  sudo usermod -aG wireshark "$USER" || exit 1
  echo "  added $USER to the wireshark group; capture works now through sg, and everywhere after the next login"
fi
