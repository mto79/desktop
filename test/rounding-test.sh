#!/usr/bin/env bash
# Windows, panels and the bar share one corner.
#
# The shell's corners come from Style.radius and the windows' from Hyprland's
# decoration:rounding, in two files nothing ties together. Changing one leaves the desktop
# with two different corners side by side.
source "$(dirname "$0")/lib.sh"

STYLE="$ROOT/shell/Commons/Style.qml"
LOOK="$ROOT/config/hypr/looknfeel.conf"

shell_radius=$(sed -nE 's/^  property int radius: ([0-9]+)$/\1/p' "$STYLE")
hypr_radius=$(sed -nE 's/^\s*rounding\s*=\s*([0-9]+)\s*$/\1/p' "$LOOK" | head -1)
if [[ -n $shell_radius && $shell_radius == "${hypr_radius:-0}" ]]; then
  pass "window rounding matches the shell's radius ($shell_radius)"
else
  fail "window rounding matches the shell's radius" \
    "Style.radius is '${shell_radius}', decoration:rounding in ${LOOK#$ROOT/} is '${hypr_radius:-unset}'"
fi

# PanelMeter used to take Style.radius whenever it was non-zero, so rounding the shell
# squared the ends off every memory and CPU meter. A meter is a pill whatever the boxes
# around it do.
# Code only: the comment saying why it does not use Style.radius names it.
if grep -vE '^\s*//' "$ROOT/shell/Ui/PanelMeter.qml" | grep -q 'Style\.radius'; then
  fail "meters stay pills whatever the shell's radius" "PanelMeter.qml reads Style.radius again"
else
  pass "meters stay pills whatever the shell's radius"
fi
finish
