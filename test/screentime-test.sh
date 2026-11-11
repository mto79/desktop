#!/usr/bin/env bash
# Screen time: what the dashboard's start page says the screen was used for. What is checked:
# a minute counts only when the screen is unlocked and not idle, and only once; the window
# in front is written down as something readable; the report adds the minutes up by day and
# by app; and the brief passes it on for the start page.
#
# hyprctl and pidof are stubs, told what is in front and whether hyprlock is up.
source "$(dirname "$0")/lib.sh"

require jq || finish

ST="$ROOT/bin/desktop-screentime"
sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
stubs="$sandbox/stubs"
mkdir -p "$stubs" "$sandbox/run"

cat >"$stubs/hyprctl" <<STUB
#!/usr/bin/env bash
[[ -e "$sandbox/no-compositor" ]] && exit 1
printf '{"class":"%s"}\n' "\$(cat "$sandbox/class" 2>/dev/null)"
STUB
cat >"$stubs/pidof" <<STUB
#!/usr/bin/env bash
[[ -e "$sandbox/locked" ]]
STUB
chmod +x "$stubs/hyprctl" "$stubs/pidof"

st() { PATH="$stubs:$PATH" XDG_STATE_HOME="$sandbox/state" XDG_RUNTIME_DIR="$sandbox/run" bash "$ST" "$@"; }
today="$sandbox/state/desktop/screentime/$(date +%F)"
front() { echo "$1" >"$sandbox/class"; rm -f "$today"; st record; tail -n1 "$today" 2>/dev/null | cut -d' ' -f2-; }

check "a terminal is a terminal" test "$(front com.mitchellh.ghostty)" = Terminal
check "a web app is its site" test "$(front 'brave-teams.microsoft.com__-Default')" = teams.microsoft.com
check "without its www" test "$(front 'brave-www.example.com__-Default')" = example.com
check "a reverse-DNS class is its last word" test "$(front md.obsidian.Obsidian)" = Obsidian
check "the browser is Brave" test "$(front brave-browser)" = Brave
check "no window in front is the desktop" test "$(front '')" = Desktop
check "and so is the shell's own window" test "$(front org.quickshell)" = Desktop

rm -rf "$sandbox/state"
echo brave-browser >"$sandbox/class"
st record
st record
check "a minute is counted once, however often the timer fires in it" test "$(wc -l <"$today")" = 1

touch "$sandbox/locked"
rm -f "$today"
st record
check "nothing is counted while the screen is locked" test ! -e "$today"
rm "$sandbox/locked"

touch "$sandbox/run/desktop-idle"
st record
check "nor while hypridle says it is idle" test ! -e "$today"
rm "$sandbox/run/desktop-idle"

touch "$sandbox/no-compositor"
st record
check "nor with no compositor to ask" test ! -e "$today"
rm "$sandbox/no-compositor"

dir="$sandbox/state/desktop/screentime"
mkdir -p "$dir"
printf '09:%02d Terminal\n' {0..29} >"$today"
printf '10:%02d Brave\n' {0..9} >>"$today"
printf '11:%02d teams.microsoft.com\n' {0..19} >>"$today"
yesterday="$dir/$(date -d '-1 day' +%F)"
printf '09:%02d Brave\n' {0..59} >"$yesterday"
old="$dir/$(date -d '-9 day' +%F)"
printf '09:00 Brave\n' >"$old"

report=$(st --json)
check "today's minutes are added up" test "$(jq .today <<<"$report")" = 60
check "the week is seven days, ending today" \
  test "$(jq -r '[.week | length, .[-1].date] | join(" ")' <<<"$report")" = "7 $(date +%F)"
check "with yesterday's minutes in their place" test "$(jq '.week[-2].minutes' <<<"$report")" = 60
check "and nothing from before the week" test "$(jq '[.week[].minutes] | add' <<<"$report")" = 120
check "the average is over the days that were counted" test "$(jq .average <<<"$report")" = 60
check "today's apps, most used first" \
  test "$(jq -r '[.apps[] | "\(.name)=\(.minutes)"] | join(" ")' <<<"$report")" = "Terminal=30 teams.microsoft.com=20 Brave=10"
check "and when counting began" test "$(jq -r .since <<<"$report")" = "$(basename "$old")"

rm -rf "$sandbox/state"
check "with nothing counted yet, the report is zeros, not an error" \
  test "$(st --json | jq -c '[.today, .average, (.apps | length), .since]')" = '[0,0,0,""]'

brief=$(PATH="$ROOT/bin:$stubs:$PATH" XDG_STATE_HOME="$sandbox/state" XDG_RUNTIME_DIR="$sandbox/run" \
  bash "$ROOT/bin/desktop-brief" --json 2>/dev/null)
check "the brief carries it to the start page" test "$(jq -c '.screentime | [.today, (.week | length)]' <<<"$brief")" = '[0,7]'

check "the start page draws it" grep -q 'page.screen.today' "$ROOT/shell/Dashboard/StartPage.qml"
check "hypridle marks the screen idle" grep -q 'on-timeout = touch "$XDG_RUNTIME_DIR/desktop-idle"' "$ROOT/config/hypr/hypridle.conf"
check "and clears the mark on input" grep -q 'on-resume = rm -f "$XDG_RUNTIME_DIR/desktop-idle"' "$ROOT/config/hypr/hypridle.conf"
check "a clean install starts the timer" grep -q 'config/screentime.sh' "$ROOT/install/config/all.sh"

finish
