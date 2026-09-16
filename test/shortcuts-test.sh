#!/usr/bin/env bash
# The key a bar tooltip names, worked out from Hyprland's bindings.
#
# A hint that names the wrong key is worse than none, so what matters is the reading:
# modifier bits in the order a chord is written, a key inside the panels submap given the
# chord that enters it, a binding's fallback (`|| desktop-menu apps`) not mistaken for its
# command, and a global key preferred over the same command reached through a submap.
source "$(dirname "$0")/lib.sh"

require python3 jq || finish

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
mkdir -p "$sandbox/bin"

cat >"$sandbox/bin/hyprctl" <<'STUB'
#!/usr/bin/env bash
cat <<'JSON'
[
  {"modmask": 64, "submap": "", "key": "D", "dispatcher": "submap", "arg": "panels"},
  {"modmask": 0, "submap": "panels", "key": "escape", "dispatcher": "submap", "arg": "reset"},
  {"modmask": 0, "submap": "panels", "key": "M", "dispatcher": "exec", "arg": "desktop-shell shell togglePanel memory"},
  {"modmask": 68, "submap": "", "key": "M", "dispatcher": "exec", "arg": "desktop-meeting-capture toggle"},
  {"modmask": 0, "submap": "panels", "key": "C", "dispatcher": "exec", "arg": "desktop-meeting-capture toggle"},
  {"modmask": 72, "submap": "", "key": "space", "dispatcher": "exec", "arg": "desktop-shell shell toggleLauncher >/dev/null 2>&1 || desktop-menu apps"},
  {"modmask": 12, "submap": "", "key": "DELETE", "dispatcher": "exec", "arg": "desktop-menu power"},
  {"modmask": 0, "submap": "", "key": "XF86AudioMicMute", "dispatcher": "exec", "arg": "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"},
  {"modmask": 0, "submap": "nowhere", "key": "X", "dispatcher": "exec", "arg": "unreachable"}
]
JSON
STUB
cat >"$sandbox/bin/voxtype" <<'STUB'
#!/usr/bin/env bash
printf '[audio]\nkey = "ignored"\n\n[hotkey]\nkey = "RIGHTALT"\nmodifiers = []\nmode = "PushToTalk"\n'
STUB
chmod +x "$sandbox/bin/"*

table=$(PATH="$sandbox/bin:$PATH" "$ROOT/bin/desktop-shortcuts" --json)
exec_of() { jq -r --arg c "$1" '.exec[$c] // ""' <<<"$table"; }

check "a panel key is written with the chord that enters the submap" \
  test "$(jq -r .panel.memory <<<"$table")" = "Super+D, then M"
check "modifiers are written in chord order" test "$(exec_of "desktop-meeting-capture toggle")" = "Super+Ctrl+M"
check "the fallback after || is not taken for the command" test "$(exec_of "desktop-shell shell toggleLauncher")" = "Super+Alt+Space"
check "an all-caps key name is written as a key is" test "$(exec_of "desktop-menu power")" = "Ctrl+Alt+Delete"
check "a media key gets a readable name" test "$(exec_of "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle")" = "Mic mute key"
check "a key in a submap nothing enters is left out" test "$(exec_of unreachable)" = ""
check "dictation comes from voxtype's hotkey section, not the first key= line" \
  test "$(jq -r .dictation <<<"$table")" = "Right Alt, hold"

# The shell must still get a table, not an error, where there is no Hyprland to ask.
mkdir -p "$sandbox/empty"
ln -s "$(command -v python3)" "$sandbox/empty/python3"
check "without hyprctl or voxtype it prints an empty table" \
  test "$(PATH="$sandbox/empty" "$ROOT/bin/desktop-shortcuts" --json)" = '{"exec": {}, "panel": {}}'

finish
