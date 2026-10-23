#!/usr/bin/env bash
# WirePlumber must not load libcamera.
#
# It owns every audio device, and libcamera inside it has taken them all down twice: an
# abort on the NVIDIA GPU, then a thread stuck in the kernel on the built-in IPU6 camera
# after a hub replug, which left the hub's USB sound card without a sink until a reboot.
source "$(dirname "$0")/lib.sh"

CONF="$ROOT/config/wireplumber/wireplumber.conf.d/50-no-libcamera.conf"

if grep -Eq '^\s*monitor\.libcamera\s*=\s*disabled' "$CONF" 2>/dev/null; then
  pass "WirePlumber's main profile disables the libcamera monitor"
else
  fail "WirePlumber's main profile disables the libcamera monitor" \
    "no 'monitor.libcamera = disabled' in ${CONF#$ROOT/}"
fi

# The USB webcams come through V4L2; turning that off as well would lose them.
if grep -Eq 'monitor\.v4l2\s*=\s*disabled' "$CONF" 2>/dev/null; then
  fail "the V4L2 monitor stays on for the USB webcams"
else
  pass "the V4L2 monitor stays on for the USB webcams"
fi

# config/ does nothing until copied; existing machines need a migration.
if grep -lq '50-no-libcamera.conf' "$ROOT"/migrations/*.sh 2>/dev/null; then
  pass "a migration deploys the drop-in to existing machines"
else
  fail "a migration deploys the drop-in to existing machines"
fi
finish
