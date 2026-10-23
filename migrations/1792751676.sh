#!/usr/bin/env bash

# ClamAV's signatures, on machines installed while the packaging script asked for
# clamav-update -- a name Fedora 44 no longer has, so the scanner went in without
# anything to match against. Safe to re-run: dnf, enable and a fresh fetch each leave a
# machine that already has them as it was.

if ! rpm -q clamav-freshclam >/dev/null 2>&1; then
  # --disablerepo because pgAdmin4's repo fails GPG verification, and one bad repo stops
  # a transaction that has nothing to do with it.
  sudo dnf install -y --disablerepo=pgAdmin4 clamav-freshclam || exit 1
  echo "  installed clamav-freshclam"
fi
sudo systemctl enable --now clamav-freshclam-once.timer || exit 1
if sudo systemctl start clamav-freshclam-once.service; then
  echo "  ClamAV's signatures are up to date, and the timer keeps them so"
else
  echo "  freshclam could not fetch signatures yet; the timer will try again"
fi
