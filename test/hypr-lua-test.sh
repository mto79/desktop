#!/usr/bin/env bash
# The Lua config Hyprland 0.57 will require, checked by Hyprland itself.
#
# hyprland.conf and its hyprlang files stop being read in 0.57; hyprland.lua and its
# twins replace them. Until the switch both are kept, file for file, so this checks the
# Lua half the way Hyprland will load it: --verify-config, from a home laid out as a real
# one -- the repo's defaults, ~/.config/hypr, the active theme -- once per theme. That
# catches what a conversion gets wrong: an option, a window-rule effect or match that
# does not exist, a dispatcher given arguments it does not take, a file that fails to load.
#
# It also keeps the two halves in step: every hyprlang file has its Lua twin, so a rule
# added to one and not the other cannot slip through before the .conf files are retired.
source "$(dirname "$0")/lib.sh"

require Hyprland || finish

# The entry file is hyprland.next.lua until the switch -- see the note at its top -- and
# hyprland.lua after it.
ENTRY=hyprland.next.lua
[[ -f $ROOT/config/hypr/hyprland.lua ]] && ENTRY=hyprland.lua

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
mkdir -p "$sandbox/.local/share" "$sandbox/.config/hypr" "$sandbox/.config/desktop/current"
ln -s "$ROOT" "$sandbox/.local/share/desktop"
cp "$ROOT"/config/hypr/*.lua "$sandbox/.config/hypr/"

for theme in "$ROOT"/themes/*/; do
  name=$(basename "$theme")
  ln -sfn "$theme" "$sandbox/.config/desktop/current/theme"
  result=$(cd "$sandbox" && HOME="$sandbox" timeout 60 Hyprland --verify-config -c "$sandbox/.config/hypr/$ENTRY" 2>&1 |
    sed -n '/Config parsing result/,$p' | grep -v '^$' | tail -n +2)
  if [[ $result == "config ok" ]]; then
    pass "the Lua config loads cleanly with the $name theme"
  else
    fail "the Lua config loads cleanly with the $name theme" "$(head -3 <<<"$result")"
  fi
done

# hyprlock, hypridle and hyprsunset are other programs, which keep hyprlang.
missing=()
while read -r conf; do
  twin=${conf%.conf}.lua
  [[ $conf == */config/hypr/hyprland.conf ]] && twin=$ROOT/config/hypr/$ENTRY
  [[ -f $twin ]] || missing+=("${conf#"$ROOT"/}")
done < <(find "$ROOT/default/hypr" "$ROOT/config/hypr" "$ROOT"/themes/*/hyprland.conf -name '*.conf' \
  ! -name 'hyprlock.conf' ! -name 'hypridle.conf' ! -name 'hyprsunset.conf')
if ((${#missing[@]} == 0)); then
  pass "every Hyprland .conf file has its .lua twin"
else
  fail "every Hyprland .conf file has its .lua twin" "no .lua for: ${missing[*]}"
fi

finish
