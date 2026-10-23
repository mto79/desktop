#!/usr/bin/env bash

# ClamAV for scanning by hand -- downloads, USB sticks, files on their way to someone
# else -- and not on access: clamd holds the signatures in about a gigabyte of memory,
# for malware that is overwhelmingly written for Windows.
#
# The signatures come from clamav-freshclam, which Fedora 44 split out of what was
# clamav-update. Asking for the old name installed the scanner alone, with an empty
# /var/lib/clamav, and a scan with nothing to match against passes everything. The
# -once timer fetches updates on a schedule instead of keeping freshclam running as a
# daemon; the first fetch is started here so the scanner works before the timer fires.
echo "Install ClamAV"
sudo dnf install -y --disablerepo=pgAdmin4 clamav clamav-freshclam
sudo systemctl enable --now clamav-freshclam-once.timer
sudo systemctl start clamav-freshclam-once.service ||
  echo "  freshclam could not fetch signatures yet; the timer will try again"
