#!/usr/bin/env bash
#
# signal.sh — Signal Desktop, from Flathub.
#
# This used to add openSUSE's OBS repository, which builds Signal per Fedora release.
# That worked until it did not: OBS publishes Fedora_42, Fedora_43 and Rawhide, and had
# still shipped nothing for Fedora 44 by the time this machine wanted to upgrade to it.
#
# The break is not in signal-desktop but in nodejs-electron, which comes from the same
# repository and is built unbundled -- it links the system abseil and ffmpeg. The
# Fedora_43 build needs libabsl_*.so.2508.0.0, from abseil-cpp 20250814; Fedora 44 ships
# abseil-cpp 20260107, providing .so.2601.0.0, and nothing there provides 2508. So the
# repository did not merely stop updating: it made the release upgrade unresolvable,
# and dnf would either refuse the transaction or need --allowerasing to drop Signal
# halfway through. Rawhide was no escape either, being an older Signal wanting the same
# abseil.
#
# The flatpak carries its own Electron, so it depends on the Fedora release not at all.
# That ends a wait that would otherwise recur every six months.

set -euo pipefail

echo "▶ Installing Flatpak (if needed)..."
sudo dnf install -y flatpak

echo "▶ Adding Flathub repository (if not already present)..."
sudo flatpak remote-add --if-not-exists flathub \
  https://dl.flathub.org/repo/flathub.flatpakrepo

echo "▶ Installing Signal..."
flatpak install -y flathub org.signal.Signal

echo "✅ Signal installed successfully!"
echo "▶ Run it with: flatpak run org.signal.Signal"
