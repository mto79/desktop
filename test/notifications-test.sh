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

# Chromium adds a "settings" action to every web notification, which put a Settings
# button pointing at Brave's preferences under each chat message.
check "a browser's own Settings action gets no button" grep -q 'fromBrowser && id === "settings"' "$QML"
check "action buttons come from the filtered list" grep -q 'model: toast.buttons' "$QML"

# One reference -- the default for the toasts' own fontSize. Any other means a line of
# text went back to the panel size and will not follow notifications.fontSize.
uses=$(grep -c 'Style\.fontSize' "$QML")
if ((uses == 1)); then
  pass "every toast text size follows notifications.fontSize"
else
  fail "every toast text size follows notifications.fontSize" \
    "$uses references to Style.fontSize in ${QML#$ROOT/}, expected only the default"
fi

# --- the notification centre
# A toast used to be thrown away when its time was up. It is put away now, and everything
# below is one of the ways that went wrong while it was being built.
PANEL="$ROOT/shell/Bar/panels/NotificationsPanel.qml"
INBOX="$ROOT/shell/Commons/Inbox.qml"

toast_timer=$(sed -n '/^  component Toast/,$p' "$QML" | grep -A4 '^    Timer {')
check "a toast whose time is up is put away, not thrown away" grep -q 'root.retire(toast.notification)' <<<"$toast_timer"
check "and nothing in a toast expires it" lacks 'notification.expire()' <<<"$(sed -n '/^  component Toast/,$p' "$QML")"
# Retiring changes the list the stack is drawn from, which destroys the toast that asked.
check "putting one away is done from outside the toast that asked" \
  test -n "$(sed -n '/^  function retire(notification)/,/^  }/p' "$QML" | grep 'sweep.restart()')"
check "and not by changing the list in that function" \
  lacks 'retired = ' <<<"$(sed -n '/^  function retire(notification)/,/^  }/p' "$QML")"
check "what its sender called transient is still forgotten" grep -q 'if (due\[d\].transient)' "$QML"
# Counted from the rebuild, every toast still on screen got its whole timeout again each
# time another came or went.
check "a toast's time is counted from when it arrived" grep -q 'at + toast.timeout - Date.now()' "$QML"
check "what was held back does not all appear when do-not-disturb ends" \
  grep -q 'onDoNotDisturbChanged: if (!doNotDisturb) {' "$QML"
check "the list is not kept without end" grep -q 'all.length - i > keep' "$QML"

# `left` is an anchor line on every Item, and final: a property of that name fails the
# file, and with it the whole shell, to load.
check "no toast property takes the name of an anchor" \
  lacks -E '^\s+property [a-z]+ (left|right|top|bottom):' "$QML"
# open() and close() are the panel's own. A function of that name in a panel replaces the
# one that shows it, and the panel then does nothing when asked for.
for panel in "$ROOT"/shell/Bar/panels/*.qml; do
  if grep -qE '^\s+function (open|close)\(' "$panel"; then
    fail "no panel redefines open or close" "${panel#"$ROOT"/}"
    redefined=1
  fi
done
[[ -n ${redefined:-} ]] || pass "no panel redefines open or close"

check "the centre shows the notifications themselves, so their actions still work" \
  grep -q 'actions\[i\].invoke()' "$PANEL"
# Dismissing an entry changes the list from inside one of its own rows.
check "and changes the list only after the row that asked has returned" \
  test "$(grep -c 'Qt.callLater(function' "$PANEL")" -ge 3
check "do-not-disturb can end by itself" grep -q 'if (Date.now() >= root.quietUntil)' "$INBOX"
check "the store is one every part of the shell shares" grep -qx 'singleton Inbox 1.0 Inbox.qml' "$ROOT/shell/Commons/qmldir"
check "the bell is on the bar" \
  test "$(jq '[.bar.layout[][] | select(.id == "notifications")] | length' "$ROOT/config/desktop/shell.json")" = 1
check "SUPER + D, O opens the centre" \
  grep -qx 'bindd = , O, Notification centre, exec, desktop-shell shell togglePanel notifications' "$ROOT/default/hypr/bindings/utilities.conf"
check "in the Lua bindings as well" grep -q 'togglePanel notifications' "$ROOT/default/hypr/bindings/utilities.lua"
finish
