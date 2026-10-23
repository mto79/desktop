#!/usr/bin/env bash
# The Lua config Hyprland reads, checked by Hyprland itself.
#
# hyprland.lua is read in place of hyprland.conf whenever it exists, and 0.57 reads
# nothing else. The hyprlang files are kept beside it until then, so this checks the
# Lua half the way Hyprland loads it: --verify-config, from a home laid out as a real
# one -- the repo's defaults, ~/.config/hypr, the active theme -- once per theme. That
# catches what a conversion gets wrong: an option, a window-rule effect or match that
# does not exist, a dispatcher given arguments it does not take, a file that fails to load.
#
# It also keeps the two halves in step: every hyprlang file has its Lua twin, so a rule
# added to one and not the other cannot slip through before the .conf files are retired.
#
# And it holds what talks to the running compositor to the Lua dialect. A Lua session
# refuses `hyprctl dispatch workspace 3` and every `hyprctl keyword`, and a hyprlang one
# refuses `hl.dsp...`, so one call left in the old form is a button that silently does
# nothing -- which is what fifteen scripts and the bar would have been at the switch.
source "$(dirname "$0")/lib.sh"

# What still speaks hyprlang to a running Hyprland: a dispatcher by its old name, or a
# keyword. The .conf twins are hyprlang by definition and are left out -- but not
# hypridle's, hyprlock's or hyprsunset's, whose commands run against the Lua session --
# and so are comments, which may quote the old form to say why it went. One pattern,
# because grep -P refuses a second -e, and a refusal hidden by `|| true` once made this
# pass while checking nothing.
LEGACY='hyprctl(\s+-\S+)*\s+dispatch\s+(?!["'"'"']?hl\.)[a-z]|hyprctl(\s+-\S+)*\s+keyword\b'
LEGACY+='|["'"'"';]\s*dispatch\s+(?!hl\.)[a-z]+[ ,]|Hyprland\.dispatch\(\s*["'"'"'](?!hl\.)'
legacy=$(grep -rnP "$LEGACY" "$ROOT/bin" "$ROOT/shell" "$ROOT/config" "$ROOT/default" "$ROOT/install")
status=$?
legacy=$(grep -vP '^[^:]*/hypr/(?!hypridle|hyprlock|hyprsunset)[^:]*\.conf:|^[^:]*:[0-9]+:\s*(#|--|//)' <<<"$legacy")
if ((status > 1)); then
  fail "nothing talks to Hyprland in the hyprlang dialect a Lua session refuses" "grep could not run the pattern"
elif [[ -z $legacy ]]; then
  pass "nothing talks to Hyprland in the hyprlang dialect a Lua session refuses"
else
  fail "nothing talks to Hyprland in the hyprlang dialect a Lua session refuses" "$(head -3 <<<"$legacy")"
fi

require Hyprland || finish

ENTRY=hyprland.lua

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
