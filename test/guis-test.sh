#!/usr/bin/env bash

# desktop-guis: a group's links as one browser window on workspace 1, closed with it, and
# the groups filled from a Homer dashboard.

source "$(dirname "$0")/lib.sh"

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
stubs="$sandbox/stubs"
mkdir -p "$stubs" "$sandbox/config/desktop" "$sandbox/theme" "$sandbox/run"

# Hyprland: the windows are the lines of $sandbox/windows -- address, class and title,
# tab-separated -- and a browser that starts adds one. Every dispatch is written down.
cat >"$stubs/hyprctl" <<STUB
#!/usr/bin/env bash
case "\$1" in
-j) # The workspace on screen: ws-seq's lines one a question, as you move, then ws's.
  if [[ \$2 == activeworkspace ]]; then
    if [[ -s "$sandbox/ws-seq" ]]; then ws=\$(head -1 "$sandbox/ws-seq"); sed -i 1d "$sandbox/ws-seq"
    else ws=\$(cat "$sandbox/ws" 2>/dev/null || echo 3); fi
    echo "{\"id\": \$ws}"; exit
  fi
  [[ \$2 == activewindow ]] && { echo "{\"address\": \"\$(cat "$sandbox/active" 2>/dev/null)\"}"; exit; }
  touch "$sandbox/windows"
  jq -R 'split("\t") | {address: .[0], class: (.[1] // "desktop-guis"), title: (.[2] // ""), workspace: {id: ((.[3] // "1") | tonumber)}, grouped: ((.[4] // "") | split(",") | map(select(. != "")))}' "$sandbox/windows" | jq -s . ;;
dispatch) echo "dispatch \$2" >>"$sandbox/calls"
  focused=\$(sed -nE 's/^hl\.dsp\.focus.*address:([^"]+).*/\1/p' <<<"\$2")
  [[ -n \$focused ]] && echo "\$focused" >"$sandbox/active"
  gone=\$(sed -nE 's/^hl\.dsp\.window\.close.*address:([^"]+).*/\1/p' <<<"\$2")
  [[ -n \$gone ]] && sed -i "/^\$gone\t/d" "$sandbox/windows" ;;
esac
STUB
cat >"$stubs/uwsm" <<STUB
#!/usr/bin/env bash
shift 2
echo "browser \$* CONFIG=\$XDG_CONFIG_HOME BACKEND=\$GSETTINGS_BACKEND" >>"$sandbox/calls"
# The GUIs' profile makes a desktop-guis window; your own browser one of its own class,
# and as it starts -- it is never running here -- an empty window of its own beside it.
class=brave-browser name=""
[[ " \$* " == *" --class=desktop-guis "* ]] && class=desktop-guis
[[ " \$* " =~ " --window-name="([^ ]+) ]] && name=\${BASH_REMATCH[1]}
n=\$(wc -l <"$sandbox/windows")
[[ \$class == brave-browser ]] && printf '0xstart%s\tbrave-browser\tNew Tab - Brave\n' "\$n" >>"$sandbox/windows"
printf '0xnew%s\t%s\t%s\n' "\$n" "\$class" "\$name" >>"$sandbox/windows"
STUB
# Nothing of the browser's is running: it is started by what is tested.
printf '#!/usr/bin/env bash\nexit 1\n' >"$stubs/pgrep"
printf '#!/usr/bin/env bash\necho brave-browser.desktop\n' >"$stubs/xdg-settings"
printf '#!/usr/bin/env bash\necho "Test Font Mono"\n' >"$stubs/desktop-font-current"
chmod +x "$stubs"/*
: >"$sandbox/windows"
echo '{"background": "#1a1b26", "foreground": "#c0caf5", "muted": "#565f89", "accent": "#7aa2f7",
  "bar": {"background": "#11111b", "raised": "#24263a"}}' >"$sandbox/theme/shell.json"

cat >"$sandbox/config/desktop/guis.conf" <<'CONF'
# a comment
[home]
https://git.example/      GitLab
# https://off.example/    not opened

[ocp203]
https://console.ocp203.example/   OpenShift
https://argocd.ocp203.example/    Argo CD
https://k10.ocp203.example/k10/#/ Kasten   # a note
CONF

guis() {
  env -i PATH="$stubs:$ROOT/bin:/usr/bin:/bin" HOME="$sandbox/home" XDG_CONFIG_HOME="$sandbox/config" \
    XDG_STATE_HOME="$sandbox/state" XDG_DATA_HOME="$sandbox/data" XDG_RUNTIME_DIR="$sandbox/run" \
    DESKTOP_THEME_DIR="$sandbox/theme" DESKTOP_GUIS="${DESKTOP_GUIS:-}" DESKTOP_GUIS_SETTLE=0 bash "$ROOT/bin/desktop-guis" "$@" 2>&1
}

# --- a group opened
: >"$sandbox/calls"
guis open ocp203 >/dev/null
check "a group opens as one browser window, its links the tabs, commented ones left out" \
  grep -qE -- '--new-window --window-name=ocp203 https://console.ocp203.example/ https://argocd.ocp203.example/ ' "$sandbox/calls"
check "  a URL's own # kept, a comment after a space dropped" \
  grep -qE -- ' https://k10.ocp203.example/k10/#/ CONFIG=' "$sandbox/calls"
check "  in a profile of its own, with the class the workspace 1 rule matches" \
  grep -qE -- "--user-data-dir=$sandbox/state/desktop/guis/browser --class=desktop-guis " "$sandbox/calls"
check "  dressed in the theme: a theme generated from shell.json" \
  test "$(jq -c '[.theme.colors.frame, .theme.colors.toolbar]' "$sandbox/state/desktop/guis/theme/manifest.json")" = '[[17,17,27],[26,27,38]]'
check "  loaded into it" grep -qE -- "--load-extension=$sandbox/state/desktop/guis/theme " "$sandbox/calls"
check "  and the desktop's font for its tabs, through a GSettings file of its own" \
  grep -qx "font-name='Test Font Mono 11'" "$sandbox/state/desktop/guis/env/glib-2.0/settings/keyfile"
check "  which the browser is pointed at" \
  grep -qE "CONFIG=$sandbox/state/desktop/guis/env BACKEND=keyfile$" "$sandbox/calls"
check "  dark, and not bringing back the windows of last time" \
  test "$(jq -c '[.browser.theme.color_scheme2, .session.restore_on_startup]' "$sandbox/state/desktop/guis/browser/Default/Preferences")" = '[2,5]'
check "  named after its group, the name its tab in the group bar shows" \
  grep -qE -- '--window-name=ocp203 ' "$sandbox/calls"
check "the window it made is remembered" test "$(cat "$sandbox/run/desktop/guis/ocp203")" = 0xnew0
: >"$sandbox/calls"
guis open ocp203 >/dev/null
check "opened again while its window is there, nothing more is opened" lacks browser "$sandbox/calls"
check "a group with no links opens nothing" test -z "$(guis open nope; grep browser "$sandbox/calls")"

# --- home: your own browser
: >"$sandbox/calls"
guis open home >/dev/null
check "home is opened only while workspace 1 is on screen: your own browser goes where you are" \
  lacks browser "$sandbox/calls"
echo 1 >"$sandbox/ws"
guis open home >/dev/null
check "  on workspace 1, a window of your own browser named home, with [home]'s links" \
  grep -qE -- "--new-window --window-name=home https://git.example/ CONFIG=" "$sandbox/calls"
check "  your own profile, not the GUIs'" lacks -- "--window-name=home.*--user-data-dir\|--user-data-dir=.*--window-name=home" "$sandbox/calls"
check "  and remembered, though it is not of the GUIs' class" \
  grep -q "brave-browser" <<<"$(grep -F "$(cat "$sandbox/run/desktop/guis/home")" "$sandbox/windows")"
: >"$sandbox/calls"
guis open home >/dev/null
check "  opened once" lacks browser "$sandbox/calls"
check "the empty window the browser opened as it started is closed: one browser, not two" \
  lacks '^0xstart' "$sandbox/windows"
check "  and home is the one named home, not that one" \
  grep -q 'home$' <<<"$(grep -F "$(cat "$sandbox/run/desktop/guis/home")" "$sandbox/windows")"
guis close home
printf '0xrestored\tbrave-browser\thome\n' >>"$sandbox/windows"
: >"$sandbox/calls"
guis open home >/dev/null
check "a home the browser's session restore brought back is taken, not a second opened" \
  test "$(grep -c browser "$sandbox/calls")-$(cat "$sandbox/run/desktop/guis/home")" = "0-0xrestored"
guis close home
printf '[ocp203]\nhttps://console.ocp203.example/ OpenShift\n' >"$sandbox/config/desktop/guis-nohome.conf"
: >"$sandbox/calls"
DESKTOP_GUIS="$sandbox/config/desktop/guis-nohome.conf" guis open home >/dev/null
check "home opens with no links of its own, a new tab" \
  grep -qE -- "--new-window --window-name=home CONFIG=" "$sandbox/calls"
guis close home
echo 3 >"$sandbox/ws"

: >"$sandbox/calls"
guis arrange
check "arranging off workspace 1 touches nothing: nothing is pulled anywhere" lacks dispatch "$sandbox/calls"
check "  and going to workspace 1 is what arranges it, in the Lua config" \
  grep -q 'workspace.id == 1' "$ROOT/default/hypr/apps/guis.lua"

# --- closed
guis close ocp203
check "closing a group closes its window, and no other" \
  grep -qx 'dispatch hl.dsp.window.close({ window = "address:0xnew0" })' "$sandbox/calls"
check "  and forgets it" test ! -e "$sandbox/run/desktop/guis/ocp203"
: >"$sandbox/calls"
guis close ocp203
check "closing one that is not open does nothing" lacks dispatch "$sandbox/calls"

check "list says each group and how many links" \
  grep -qE '^ocp203 +closed +3 links$' <<<"$(guis list)"

# --- KeePassXC-Browser, from your own browser
brave="$sandbox/config/BraveSoftware/Brave-Browser"
for v in 1.9.0_0 1.10.4_0; do
  mkdir -p "$brave/Default/Extensions/oboonakemofpalcgghocfoadofidjkkk/$v"
  echo '{}' >"$brave/Default/Extensions/oboonakemofpalcgghocfoadofidjkkk/$v/manifest.json"
  mkdir -p "$brave/Default/Extensions/oboonakemofpalcgghocfoadofidjkkk/$v/_metadata"
  echo '{}' >"$brave/Default/Extensions/oboonakemofpalcgghocfoadofidjkkk/$v/_metadata/verified_contents.json"
done
mkdir -p "$brave/NativeMessagingHosts"
echo '{}' >"$brave/NativeMessagingHosts/org.keepassxc.keepassxc_browser.json"
: >"$sandbox/calls"
guis open ocp203 >/dev/null
check "KeePassXC-Browser, as your own browser has it, is loaded beside the theme, the newest" \
  grep -qE -- "--load-extension=$sandbox/state/desktop/guis/theme,$sandbox/state/desktop/guis/keepassxc-browser/1.10.4_0 " "$sandbox/calls"
check "  a copy of it: your own browser's folder is never loaded, which deletes its _metadata" \
  lacks -- "--load-extension=.*BraveSoftware" "$sandbox/calls"
check "  the copy without the _metadata a loaded folder may not have" \
  test -f "$sandbox/state/desktop/guis/keepassxc-browser/1.10.4_0/manifest.json" -a \
    ! -e "$sandbox/state/desktop/guis/keepassxc-browser/1.10.4_0/_metadata"
check "  and the original left whole, the Store's checksums in it" \
  test -f "$brave/Default/Extensions/oboonakemofpalcgghocfoadofidjkkk/1.10.4_0/_metadata/verified_contents.json"
check "  and KeePassXC's host is there for it, under the XDG_CONFIG_HOME the browser is given" \
  test "$(readlink "$sandbox/state/desktop/guis/env/BraveSoftware/Brave-Browser/NativeMessagingHosts/org.keepassxc.keepassxc_browser.json")" = "$brave/NativeMessagingHosts/org.keepassxc.keepassxc_browser.json"
guis close ocp203
rm -rf "$sandbox/config/BraveSoftware"

# --- arranging only while you are there
printf '0xa\tdesktop-guis\tocp202\n0xb\tdesktop-guis\tocp203\n' >"$sandbox/windows"
mkdir -p "$sandbox/run/desktop/guis"
echo 0xa >"$sandbox/run/desktop/guis/home"
echo 0xb >"$sandbox/run/desktop/guis/ocp203"
echo 0xother >"$sandbox/active"
# On workspace 1 as arranging starts, gone by its first focus.
printf '1\n' >"$sandbox/ws-seq"
: >"$sandbox/calls"
guis arrange
check "leaving workspace 1 while it is arranged, nothing is focused: you are not pulled back" \
  lacks dispatch "$sandbox/calls"
# There for the first focus, gone before the window is moved into the group.
printf '1\n1\n' >"$sandbox/ws-seq"
: >"$sandbox/calls"
guis arrange
check "  gone partway, nothing is moved and the focus is not given back from there" \
  test "$(grep -c dispatch "$sandbox/calls")" = 1
rm -f "$sandbox/ws-seq" "$sandbox/run/desktop/guis/home" "$sandbox/run/desktop/guis/ocp203"
: >"$sandbox/windows"

# --- home brought to workspace 1
# Opened while you were on workspace 2 -- the browser slow to start at login -- home was
# left there. The fourth column is a window's workspace.
printf '0xhome\tbrave-browser\thome\t2\t0xhome,0xteams\n0xteams\tbrave-teams\tTeams\t2\t0xhome,0xteams\n' >"$sandbox/windows"
mkdir -p "$sandbox/run/desktop/guis"
echo 0xhome >"$sandbox/run/desktop/guis/home"
echo 1 >"$sandbox/ws"
: >"$sandbox/calls"
guis arrange >/dev/null
check "home opened on another workspace is moved to workspace 1, without following it" \
  grep -qF 'hl.dsp.window.move({ workspace = 1, window = "address:0xhome", follow = false })' "$sandbox/calls"
check "  in a group with a window of your own, that window is let go first, not taken along" \
  test "$(grep -n -e 'out_of_group = true, window = "address:0xteams"' -e 'workspace = 1, window = "address:0xhome"' "$sandbox/calls" | cut -d: -f1 | tr '\n' ' ')" = "1 2 "
printf '0xhome\tbrave-browser\thome\t1\n' >"$sandbox/windows"
: >"$sandbox/calls"
guis arrange >/dev/null
check "  and home already there is not moved" lacks 'workspace = 1, window' "$sandbox/calls"
rm -f "$sandbox/run/desktop/guis/home"; : >"$sandbox/windows"; echo 3 >"$sandbox/ws"

# --- filled from Homer
mkdir -p "$sandbox/homer"
cat >"$sandbox/homer/config.yml" <<'YAML'
title: A dashboard
services:
  - name: Team Tools
    items:
      - name: Chat
        url: https://chat.example/
  - name: OCP202 | Development
    items:
      - name: OpenShift Development
        url: https://console.ocp202.example/
      - name: System ArgoCD
        url: https://argocd.ocp202.example/
  - name: OCP203 | Production
    items:
      - name: OpenShift Production
        url: https://console-new.ocp203.example/
YAML
guis import "file://$sandbox/homer/config.yml" >/dev/null
conf="$sandbox/config/desktop/guis.conf"
check "a Homer section named after a cluster becomes its group, every link in it" \
  test "$(sed -n '/^\[ocp202\]/,/^$/p' "$conf" | grep -c '^https')" = 2
check "  a group that was there is replaced by Homer's" \
  test "$(sed -n '/^\[ocp203\]/,/^$/p' "$conf" | grep '^https' | tr '\n' ' ')" = "https://console-new.ocp203.example/  OpenShift Production "
check "  home is kept as it was, first" test "$(grep -m1 '^\[' "$conf")" = "[home]"
check "  with what was in it" grep -qx 'https://git.example/      GitLab' "$conf"
check "  and sections that are no cluster's are left out" lacks chat.example "$conf"

finish
