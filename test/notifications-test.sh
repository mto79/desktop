#!/usr/bin/env bash
# Notification toasts read at a glance.
#
# No desktop-* script passes --app-name, so notify-send named itself as the sender and
# the header over most toasts read "notify-send". The text was also sized off the
# shell's panel font, the sender line three steps under it, which made the line saying
# who a message is from the hardest one to read.
source "$(dirname "$0")/lib.sh"

QML="$ROOT/shell/Notifications/Notifications.qml"

check "notify-send is not shown as a toast's sender" grep -q 'app === "notify-send"' "$QML"

# One reference -- the default for the toasts' own fontSize. Any other means a line of
# text went back to the panel size and will not follow notifications.fontSize.
uses=$(grep -c 'Style\.fontSize' "$QML")
if ((uses == 1)); then
  pass "every toast text size follows notifications.fontSize"
else
  fail "every toast text size follows notifications.fontSize" \
    "$uses references to Style.fontSize in ${QML#$ROOT/}, expected only the default"
fi
finish
