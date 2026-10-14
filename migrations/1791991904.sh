#!/usr/bin/env bash

# The bar's equalizer, on machines installed before it existed: it listens through cava,
# which a clean install gets from desktop-base.packages. The shell picks it up the next
# time a track plays; nothing needs restarting.

if ! rpm -q cava >/dev/null 2>&1; then
  # --disablerepo because pgAdmin4's repo fails GPG verification, and one bad repo stops
  # a transaction that has nothing to do with it.
  sudo dnf install -y --disablerepo=pgAdmin4 cava || exit 1
  echo "  installed cava; the media widget shows an equalizer while music plays"
else
  echo "  cava was already installed"
fi
