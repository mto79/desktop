#!/usr/bin/env bash

# desktop-cmd-screenshot: the picker comes up on a press, and a second press cancels it --
# but a key that arrives twice in the same instant is one press, not a start and a cancel.
# Run against stand-ins: nothing here takes a picture or opens anything.

source "$(dirname "$0")/lib.sh"

SHOT="$ROOT/bin/desktop-cmd-screenshot"
sandbox=$(mktemp -d)
stubs="$sandbox/bin"
mkdir -p "$stubs" "$sandbox/run" "$sandbox/pictures"
trap 'pkill -f "$sandbox/bin/slurp" 2>/dev/null; rm -rf "$sandbox"' EXIT

# The picker: a process called slurp that stays up until it is killed, as the real one
# stays until a region is drawn.
cat >"$stubs/hyprshot" <<STUB
#!/usr/bin/env bash
echo started >>"$sandbox/starts"
"$stubs/slurp" 20
STUB
# A copy of sleep under the picker's name, so that it is "slurp" to ps and to pkill.
cp "$(command -v sleep)" "$stubs/slurp"
printf '#!/usr/bin/env bash\necho "satty $*" >>"%s/calls"\n' "$sandbox" >"$stubs/satty"
printf '#!/usr/bin/env bash\ntrue\n' >"$stubs/notify-send"
# The journal is for real presses; here the lines are kept to be checked.
printf '#!/usr/bin/env bash\nshift 3\necho "$*" >>"%s/said"\n' "$sandbox" >"$stubs/logger"
chmod +x "$stubs"/*

press() { PATH="$stubs:$PATH" XDG_RUNTIME_DIR="$sandbox/run" DESKTOP_SCREENSHOT_DIR="$sandbox/pictures" bash "$SHOT" >/dev/null 2>&1; }
up() { pgrep -f "^$stubs/slurp 20$" | wc -l; }

press &
press &
sleep 0.6
check "a key that arrives twice at once starts one picker" test "$(wc -l <"$sandbox/starts")" = 1
check "and leaves it up" test "$(up)" = 1
sleep 1
press
sleep 0.3
check "a press a moment later is the cancel" test "$(up)" = 0
wait
check "a cancelled shot opens no editor" test ! -e "$sandbox/calls"
press &
sleep 0.4
check "and the next press starts afresh" test "$(wc -l <"$sandbox/starts")" = 2
pkill -f "^$stubs/slurp 20$"
wait
check "every press says how far it got" grep -q "second press, picker cancelled" "$sandbox/said"
check "a doubled press says it was ignored" grep -q "press ignored" "$sandbox/said"

finish
