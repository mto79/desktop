#!/usr/bin/env bash
# Which screen each starting workspace lands on, and which window the login puts there.
#
# The pin is a preference list per workspace, so what needs guarding is the fallbacks:
# a desk without a portrait screen, without an ultrawide, or with only the laptop. The
# start script needs guarding against the reason it exists -- `[workspace N]` exec rules
# put windows on the wrong workspace because the window was not the launched process's.
# It must move the window the launch opened, never one of that class already open.
source "$(dirname "$0")/lib.sh"

require jq || finish

PIN="$ROOT/bin/desktop-workspace-pin"
START="$ROOT/bin/desktop-workspace-start"

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
stubs="$sandbox/bin"
log="$sandbox/hyprctl.log"
mkdir -p "$stubs" "$sandbox/.config/hypr" "$sandbox/.local/bin"

# hyprctl answers from fixture files and records everything it is told to do.
cat >"$stubs/hyprctl" <<'STUB'
#!/usr/bin/env bash
case "$1" in
monitors) cat "$MONITORS_FIXTURE" ;;
workspaces) cat "${WORKSPACES_FIXTURE:-/dev/null}" ;;
activeworkspace) echo '{"id":3}' ;;
clients) jq -s . "$CLIENTS" 2>/dev/null || echo '[]' ;;
*) echo "$*" >>"$HYPRCTL_LOG" ;;
esac
exit 0
STUB

# name, physical width and height in mm, transform
screen() {
  printf '{"name":"%s","physicalWidth":%s,"physicalHeight":%s,"transform":%s,"disabled":false}' "$@"
}
LAPTOP=$(screen eDP-1 350 220 0)
ULTRAWIDE=$(screen DP-7 800 340 0)
PORTRAIT=$(screen DP-8 600 340 1)

pins_for() {
  local fixture="$sandbox/monitors.json"
  local IFS=,
  echo "[$*]" >"$fixture"
  MONITORS_FIXTURE="$fixture" HOME="$sandbox" PATH="$stubs:$PATH" bash "$PIN" --print 2>/dev/null |
    tr '\n' ' ' | sed 's/ $//'
}
chmod +x "$stubs/hyprctl"

check "the whole home desk: laptop, portrait, ultrawide" \
  test "$(pins_for "$LAPTOP" "$ULTRAWIDE" "$PORTRAIT")" = "1 eDP-1 2 DP-8 3 DP-7 4 eDP-1 5 DP-8"

check "without the portrait screen, chat goes to the ultrawide and notes to the laptop" \
  test "$(pins_for "$LAPTOP" "$ULTRAWIDE")" = "1 eDP-1 2 DP-7 3 DP-7 4 eDP-1 5 eDP-1"

check "without the ultrawide, the terminal goes to the laptop, not the portrait screen" \
  test "$(pins_for "$LAPTOP" "$PORTRAIT")" = "1 eDP-1 2 DP-8 3 eDP-1 4 eDP-1 5 DP-8"

check "the laptop on its own holds every workspace" \
  test "$(pins_for "$LAPTOP")" = "1 eDP-1 2 eDP-1 3 eDP-1 4 eDP-1 5 eDP-1"

# Applying: the rules are written, and only a workspace on the wrong screen is moved.
echo "[$LAPTOP,$ULTRAWIDE,$PORTRAIT]" >"$sandbox/monitors.json"
cat >"$sandbox/workspaces.json" <<'JSON'
[{"id":1,"monitor":"eDP-1"},{"id":2,"monitor":"DP-7"},{"id":3,"monitor":"DP-8"}]
JSON
MONITORS_FIXTURE="$sandbox/monitors.json" WORKSPACES_FIXTURE="$sandbox/workspaces.json" \
  HYPRCTL_LOG="$log" HOME="$sandbox" PATH="$stubs:$PATH" bash "$PIN"

CONF="$sandbox/.config/hypr/workspaces.conf"
check "the rules are written for the next reload" \
  test "$(grep -c '^workspace = ' "$CONF")" = 5
check "workspace 2 is written to the portrait screen" grep -qx "workspace = 2, monitor:DP-8" "$CONF"
check "a misplaced workspace is moved" grep -qx "dispatch moveworkspacetomonitor 3 DP-7" "$log"
check "a workspace already in place is not moved" lacks "moveworkspacetomonitor 1 " "$log"
check "the focus is handed back after moving" grep -qx "dispatch workspace 3" "$log"

# A desk that reports no physical size matches no kind; that must not write a broken rule.
echo '[{"name":"HDMI-A-1","physicalWidth":0,"physicalHeight":0,"transform":0,"disabled":false}]' \
  >"$sandbox/monitors.json"
MONITORS_FIXTURE="$sandbox/monitors.json" DESKTOP_LAPTOP_MONITOR=none HYPRCTL_LOG="$log" \
  HOME="$sandbox" PATH="$stubs:$PATH" bash "$PIN" 2>/dev/null
check "no screen of any kind writes no rule at all" lacks '^workspace' "$CONF"

# The start script, with every app replaced by a stub that maps a window of its class.
: >"$log"
clients="$sandbox/clients.jsonl"
# The window someone already had open. It shares a class with two of the launches.
echo '{"address":"0xexisting","class":"com.mitchellh.ghostty","workspace":{"id":7}}' >"$clients"

cat >"$stubs/fake-app" <<'STUB'
#!/usr/bin/env bash
# Maps "a window" of the class the command would open, after a moment, like a real app.
class="$1"; shift
sleep 0.3
printf '{"address":"0x%s","class":"%s","workspace":{"id":9}}\n' \
  "$(printf '%s' "$*" | md5sum | cut -c1-8)" "$class" >>"$CLIENTS"
STUB
cat >"$stubs/uwsm" <<'STUB'
#!/usr/bin/env bash
shift 2  # app --
case "$1" in
brave-browser) exec fake-app brave-browser "$@" ;;
ghostty) exec fake-app com.mitchellh.ghostty "$@" ;;
esac
STUB
cat >"$stubs/desktop-launch-webapp" <<'STUB'
#!/usr/bin/env bash
host=${1#https://}
exec fake-app "brave-${host%%/*}__-Default" "$@"
STUB
printf '#!/usr/bin/env bash\nexec fake-app org.keepassxc.KeePassXC keepassxc\n' >"$sandbox/.local/bin/KeePassXC.AppImage"
printf '#!/usr/bin/env bash\nexec fake-app md.obsidian.Obsidian obsidian\n' >"$sandbox/.local/bin/Obsidian.AppImage"
printf '#!/usr/bin/env bash\necho "$*" >>"$TMUX_LOG"\n[[ $1 != has-session ]]\n' >"$stubs/tmux"
# Not a noop: what matters is that the login lays the llm-wiki session out, and with
# which agent. The layout itself has its own suite.
printf '#!/usr/bin/env bash\necho "$*" >>"$LAYOUT_LOG"\n' >"$stubs/desktop-agent-layout"
for noop in desktop-workspace-pin notify-send; do
  printf '#!/usr/bin/env bash\nexit 0\n' >"$stubs/$noop"
done
chmod +x "$stubs"/* "$sandbox/.local/bin"/*

CLIENTS="$clients" HYPRCTL_LOG="$log" TMUX_LOG="$sandbox/tmux.log" HOME="$sandbox" \
  LAYOUT_LOG="$sandbox/layout.log" \
  DESKTOP_WORKSPACE_START_TIMEOUT=5 PATH="$stubs:$PATH" timeout 30 bash "$START"

moved_to() {
  local address
  address="0x$(printf '%s' "$2" | md5sum | cut -c1-8)"
  grep -qx "dispatch movetoworkspacesilent $1,address:$address" "$log"
}
check "Brave is moved to workspace 1" moved_to 1 "brave-browser"
check "tmux is moved to workspace 3" moved_to 3 "ghostty -e tmux attach-session -t home"
check "Mattermost is moved to workspace 2" moved_to 2 "https://chat.nationaalarchief.nl"
check "Teams is moved to workspace 2" moved_to 2 "https://teams.microsoft.com"
check "KeePassXC is moved to workspace 4" moved_to 4 "keepassxc"
check "Obsidian is moved to workspace 5" moved_to 5 "obsidian"
check "a terminal that was already open is left where it is" \
  lacks "0xexisting" "$log"
check "the home tmux session is created" grep -q "new-session -d -s home" "$sandbox/tmux.log"
check "the llm-wiki tmux session is created" grep -q "new-session -d -s llm-wiki" "$sandbox/tmux.log"
check "llm-wiki is laid out with claude, so it is ready when you switch to it" \
  grep -qx "llm-wiki:ide claude" "$sandbox/layout.log"
check "home is left a plain shell" lacks "^home" "$sandbox/layout.log"
check "the focus ends on the terminal's workspace" grep -q "dispatch workspace 3$" "$log"

finish
