#!/usr/bin/env bash
# The polkit agent's dialog has to be able to draw.
#
# hyprpolkitagent styles itself with org.hyprland.style from hyprland-qt-support, a plugin
# built against Qt's private API. After the Fedora 44 upgrade the copr's build no longer
# loaded against Qt 6.11.2, so no prompt ever appeared and KeePassXC's Unlock hung until
# polkit gave up. The fix names a stock Qt style in a drop-in for the agent's unit.
source "$(dirname "$0")/lib.sh"

DROPIN="$ROOT/config/systemd/user/hyprpolkitagent.service.d/qt-style.conf"

style=$(sed -n 's/^Environment=QT_QUICK_CONTROLS_STYLE=//p' "$DROPIN" 2>/dev/null)
if [[ -n $style ]]; then
  pass "the polkit agent's unit names its Quick Controls style"
else
  fail "the polkit agent's unit names its Quick Controls style" \
    "no QT_QUICK_CONTROLS_STYLE in ${DROPIN#$ROOT/} -- the agent falls back to org.hyprland.style"
fi

# A style Qt does not have fails exactly like the broken one does, so check it exists
# where the agent will look. Only meaningful where Qt is installed.
qml=/usr/lib64/qt6/qml/QtQuick/Controls
if [[ -n $style && -d $qml ]]; then
  check "the style it names ships with Qt ($style)" test -d "$qml/$style"
fi

# config/ does nothing until it is copied, and install/config/config.sh only runs on a
# fresh install. Without a migration every existing machine keeps the broken prompt.
if grep -lq 'hyprpolkitagent.service.d' "$ROOT"/migrations/*.sh 2>/dev/null; then
  pass "a migration deploys the drop-in to existing machines"
else
  fail "a migration deploys the drop-in to existing machines"
fi
finish
