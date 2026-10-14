#!/usr/bin/env bash
# The bar's equalizer listens through cava with default/cava/spectrum.conf. Fedora's cava
# has no PipeWire input, and naming it made cava exit on reading the config -- the widget
# quietly kept its glyph and nothing said why. So: does this cava, with this config,
# print frames?
source "$(dirname "$0")/lib.sh"
require cava || finish

CONF="$ROOT/default/cava/spectrum.conf"

out=$(timeout 2 cava -p "$CONF" 2>&1)
check "cava accepts the equalizer's config" lacks -q "Error" <<<"$out"
check "and prints frames of twelve levels" \
  grep -qE '^([0-9]+;){12}$' <<<"$out"

finish
