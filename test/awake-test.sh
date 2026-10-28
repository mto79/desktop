#!/usr/bin/env bash
# The screen stays on through a call. hypridle locked and blanked the screen eighteen
# minutes into one, because listening and watching are not typing. The shell now holds an
# idle inhibitor while a microphone records or the screen is shared, and by hand.
source "$(dirname "$0")/lib.sh"

SHELL_DIR="$ROOT/shell"
AWAKE="$SHELL_DIR/Commons/Awake.qml"
SOUND="$SHELL_DIR/Commons/Sound.qml"

check "Awake is a registered singleton" grep -q '^singleton Awake 1.0 Awake.qml$' "$SHELL_DIR/Commons/qmldir"
check "a call keeps the screen on" grep -q 'readonly property bool call: Sound.recording' "$AWAKE"
check "so does a screen share" grep -q 'readonly property bool sharing: Sharing.active' "$AWAKE"
check "and a hold by hand" grep -q 'readonly property bool active: held || call || sharing' "$AWAKE"

# The inhibitor needs a window, and the compositor only honours it while that window is
# on a screen: every bar carries one.
check "every bar holds an inhibitor that follows Awake" \
  test -n "$(sed -n '/IdleInhibitor {/,/}/p' "$SHELL_DIR/Bar/Bar.qml" | grep 'enabled: Awake.active')"

# cava records the speakers' monitor to draw the equalizer. Counted as a microphone, music
# alone would keep the screen on, and the microphone icon lit.
check "a recording of the speakers is not a microphone" \
  grep -q 'flowing(groups, "target", PwNodeType.AudioInStream, true)' "$SOUND"
check "which is told by the sink at the other end" grep -q 'group.source.isSink' "$SOUND"

# hypridle can be told to ignore inhibitors, and then none of the above does anything.
check "hypridle honours idle inhibitors" bash -c "! grep -qE 'ignore_wayland_inhibit *= *(true|1)' '$ROOT/config/hypr/hypridle.conf'"

# SUPER + CTRL + I goes to the shell, which shows the hold on the bar; only without the
# shell does it fall back to stopping hypridle.
sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
mkdir -p "$sandbox/bin"
printf '#!/usr/bin/env bash\necho "${SHELL_ANSWER:-}"\n' >"$sandbox/bin/desktop-shell"
for tool in pgrep pkill notify-send uwsm; do
  printf '#!/usr/bin/env bash\necho %s >>"%s/called"\n' "$tool" "$sandbox" >"$sandbox/bin/$tool"
done
chmod +x "$sandbox/bin"/*
PATH="$sandbox/bin:$PATH" SHELL_ANSWER=held "$ROOT/bin/desktop-toggle-idle"
check "with the shell up, the toggle leaves hypridle alone" test ! -e "$sandbox/called"
PATH="$sandbox/bin:$PATH" SHELL_ANSWER= "$ROOT/bin/desktop-toggle-idle"
check "without it, hypridle is stopped or started as before" grep -q pgrep "$sandbox/called"

finish
