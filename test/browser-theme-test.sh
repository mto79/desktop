#!/usr/bin/env bash

# desktop-browser-theme: Brave and Chromium through a theme their launchers load, Firefox
# through userChrome.css, all from the theme's shell.json.

source "$(dirname "$0")/lib.sh"

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
mkdir -p "$sandbox/theme" "$sandbox/system" "$sandbox/stubs" "$sandbox/ff/abc.default" "$sandbox/ff/def.other/chrome"
echo '{"background": "#1a1b26", "foreground": "#c0caf5", "muted": "#565f89", "accent": "#7aa2f7",
  "bar": {"background": "#11111b", "raised": "#24263a"}}' >"$sandbox/theme/shell.json"
printf '#!/usr/bin/env bash\necho "Test Font"\n' >"$sandbox/stubs/desktop-font-current"
chmod +x "$sandbox/stubs/desktop-font-current"

cat >"$sandbox/system/brave-browser.desktop" <<'EOF'
[Desktop Entry]
Name=Brave
Exec=/usr/bin/brave-browser-stable %U

[Desktop Action new-private-window]
Exec=/usr/bin/brave-browser-stable --incognito
EOF
printf '[Profile0]\nPath=abc.default\n\n[Profile1]\nPath=def.other\n' >"$sandbox/ff/profiles.ini"
echo '#nav-bar { mine: yes; }' >"$sandbox/ff/def.other/chrome/userChrome.css"

theme() {
  env -i PATH="$sandbox/stubs:/usr/bin:/bin" HOME="$sandbox/home" XDG_STATE_HOME="$sandbox/state" \
    XDG_DATA_HOME="$sandbox/data" DESKTOP_THEME_DIR="$sandbox/theme" DESKTOP_SYSTEM_APPS="$sandbox/system" \
    DESKTOP_FIREFOX_DIR="$sandbox/ff" bash "$ROOT/bin/desktop-browser-theme" "$@" 2>&1
}

theme
manifest="$sandbox/state/desktop/browser-theme/chromium/manifest.json"
check "a Chromium theme from shell.json: the tab strip the bar's colour, the toolbar the background" \
  test "$(jq -c '[.theme.colors.frame, .theme.colors.toolbar]' "$manifest")" = '[[17,17,27],[26,27,38]]'
entry="$sandbox/data/applications/brave-browser.desktop"
check "Brave's launcher loads it, in every way it is started" \
  test "$(grep -c -- "--load-extension=$sandbox/state/desktop/browser-theme/chromium" "$entry")" = 2
check "  with what each started with kept" grep -q -- 'chromium --incognito$' "$entry"
check "  and marked as this one's" grep -qx 'X-Desktop-Generated=desktop-browser-theme' "$entry"
check "a browser that is not installed gets no launcher" test ! -e "$sandbox/data/applications/chromium-browser.desktop"
theme
check "written again, not twice over" test "$(grep -c -- '--load-extension' "$entry")" = 2
printf '[Desktop Entry]\nExec=mine\n' >"$entry"
out=$(theme)
check "a launcher of your own is left alone" grep -qx 'Exec=mine' "$entry"
check "  and said so" grep -q 'is your own' <<<"$out"

check "every Firefox profile gets the colours" \
  test "$(grep -l -- '--toolbox-bgcolor: #11111b' "$sandbox"/ff/*/chrome/desktop-theme.css | wc -l)" = 2
check "  and the desktop's font" grep -q 'font-family: "Test Font"' "$sandbox/ff/abc.default/chrome/desktop-theme.css"
check "  through userChrome.css, which imports it first" \
  test "$(head -1 "$sandbox/ff/def.other/chrome/userChrome.css")" = '@import "desktop-theme.css";'
check "  made where a profile had none" \
  test "$(cat "$sandbox/ff/abc.default/chrome/userChrome.css")" = '@import "desktop-theme.css";'
check "  one of your own kept, beneath" grep -q 'mine: yes' "$sandbox/ff/def.other/chrome/userChrome.css"
check "  and imported once, however often it runs" \
  test "$(grep -c '@import' "$sandbox/ff/def.other/chrome/userChrome.css")" = 1
check "  with Firefox told to read it" \
  test "$(grep -c 'legacyUserProfileCustomizations' "$sandbox/ff/abc.default/user.js")" = 1

finish
