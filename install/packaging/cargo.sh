#!/usr/bin/env bash

# Packages for cargo builds
sudo dnf install -y \
  cargo \
  clang \
  pipewire-devel

# Build cargo bins.
#
# --locked for the reason spelled out in bin/desktop-update-cargo: without it cargo
# re-resolves dependencies to the newest semver-compatible versions rather than the ones
# each crate was published against, and a mismatched proc-macro takes the build down.
# All four publish a Cargo.lock, so none of them is left unbuildable by this.
#
# impala is the Wi-Fi TUI that desktop-launch-wifi, the network panel's Advanced row and
# the network widget's right click all reach for; it was installed here by hand and
# never listed, so a clean install had three dead ends.
cargo install --locked \
  bluetui \
  cargo-update \
  eza \
  impala
