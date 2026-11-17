#!/usr/bin/env bash

# desktop-guis: a group's links as one browser window on workspace 1, closed with it, and
# the groups filled from a Homer dashboard.

source "$(dirname "$0")/lib.sh"

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
stubs="$sandbox/stubs"
mkdir -p "$stubs" "$sandbox/config/desktop" "$sandbox/theme" "$sandbox/run"

# Hyprland: the windows of class desktop-guis are those listed in $sandbox/windows, and a
# browser that starts adds one. Every dispatch is written down.
cat >"$stubs/hyprctl" <<STUB
#!/usr/bin/env bash
case "\$1" in
-j) [[ \$2 == activeworkspace ]] && { echo '{"id": 3}'; exit; }
  touch "$sandbox/windows"; jq -R '{class: "desktop-guis", address: ., workspace: {id: 1}, grouped: []}' "$sandbox/windows" | jq -s . ;;
dispatch) echo "dispatch \$2" >>"$sandbox/calls"
  gone=\$(sed -nE 's/.*address:([^"]+).*/\1/p' <<<"\$2")
  [[ -n \$gone ]] && sed -i "/^\$gone\$/d" "$sandbox/windows" ;;
esac
STUB
cat >"$stubs/uwsm" <<STUB
#!/usr/bin/env bash
shift 2
echo "browser \$* CONFIG=\$XDG_CONFIG_HOME BACKEND=\$GSETTINGS_BACKEND" >>"$sandbox/calls"
echo "0xnew\$(wc -l <"$sandbox/windows")" >>"$sandbox/windows"
STUB
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
CONF

guis() {
  env -i PATH="$stubs:$ROOT/bin:/usr/bin:/bin" HOME="$sandbox/home" XDG_CONFIG_HOME="$sandbox/config" \
    XDG_STATE_HOME="$sandbox/state" XDG_DATA_HOME="$sandbox/data" XDG_RUNTIME_DIR="$sandbox/run" \
    DESKTOP_THEME_DIR="$sandbox/theme" bash "$ROOT/bin/desktop-guis" "$@" 2>&1
}

# --- a group opened
: >"$sandbox/calls"
guis open ocp203 >/dev/null
check "a group opens as one browser window, its links the tabs, commented ones left out" \
  grep -qE -- '--new-window --window-name=ocp203 https://console.ocp203.example/ https://argocd.ocp203.example/ ' "$sandbox/calls"
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
  grep -qE '^ocp203 +closed +2 links$' <<<"$(guis list)"

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
