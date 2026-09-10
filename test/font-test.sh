#!/usr/bin/env bash
# Setting a font reaches the terminal, and reaches it with a font a grid can lay out.
#
# Both halves were broken and silent. ghostty's font-family line ships commented out --
# ghostty's own default is fine, so the config does not override it -- and the sed that
# rewrote it was anchored at ^font-family, so it matched nothing and every font change
# for as long as the script existed moved the bar and left the terminal behind. And the
# name the bar wants is the Propo cut of a Nerd Font, whose icons are proportional:
# handed to a terminal it knocks every prompt glyph out of its column.
source "$(dirname "$0")/lib.sh"

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
mkdir -p "$sandbox/bin" "$sandbox/.config/ghostty" "$sandbox/.config/waybar" \
  "$sandbox/.config/swayosd" "$sandbox/.config/fontconfig"

# Everything the script reaches for beyond the files under test. fc-list is the one with
# an opinion: it decides both that a font exists and that a Mono cut is available.
for stub in pkill xmlstarlet desktop-restart-shell desktop-restart-waybar desktop-restart-wofi; do
  printf '#!/usr/bin/env bash\nexit 0\n' >"$sandbox/bin/$stub"
done
cat >"$sandbox/bin/fc-list" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "JetBrainsMono NFP Medium" "JetBrainsMono NFM Medium" "Cascadia Mono NF"
STUB
chmod +x "$sandbox/bin"/*

printf 'font-family: "old";\n' >"$sandbox/.config/waybar/style.css"
printf 'font-family: "old";\n' >"$sandbox/.config/swayosd/style.css"
printf '<fontconfig/>\n' >"$sandbox/.config/fontconfig/fonts.conf"

set_font() {
  HOME="$sandbox" PATH="$sandbox/bin:$PATH" \
    bash "$ROOT/bin/desktop-font-set" "$1" >/dev/null 2>&1
}

ghostty_font() {
  grep -oP '^font-family *= *"\K[^"]+' "$sandbox/.config/ghostty/config"
}

# ---- the line ships commented out, which is what defeated the old sed

printf '# Fonts\n# font-family               = "JetBrainsMono Nerd Font Mono"\nfont-size = 12\n' \
  >"$sandbox/.config/ghostty/config"
set_font "JetBrainsMono NFP Medium"
check "a commented-out font-family gets set" test "$(ghostty_font)" = "JetBrainsMono NFM Medium"
check "the commented line is not left behind as well" \
  test "$(grep -c 'font-family' "$sandbox/.config/ghostty/config")" = 1

# ---- and the other two states it can be in

printf 'font-family = "Cascadia Mono NF"\nfont-size = 12\n' >"$sandbox/.config/ghostty/config"
set_font "JetBrainsMono NFP Medium"
check "a live font-family is rewritten" test "$(ghostty_font)" = "JetBrainsMono NFM Medium"

printf 'font-size = 12\n' >"$sandbox/.config/ghostty/config"
set_font "JetBrainsMono NFP Medium"
check "a missing font-family is added" test "$(ghostty_font)" = "JetBrainsMono NFM Medium"

# ---- the swap is a Nerd Font rule, not a rule about every font

printf 'font-size = 12\n' >"$sandbox/.config/ghostty/config"
set_font "Cascadia Mono NF"
check "a font with no Propo cut is passed through unchanged" \
  test "$(ghostty_font)" = "Cascadia Mono NF"

# ---- the bar keeps the Propo cut it asked for

waybar_font=$(grep -oP "font-family: '\K[^']+" "$sandbox/.config/waybar/style.css")
set_font "JetBrainsMono NFP Medium"
waybar_font=$(grep -oP "font-family: '\K[^']+" "$sandbox/.config/waybar/style.css")
check "the bar is given the Propo cut, not the terminal's" \
  test "$waybar_font" = "JetBrainsMono NFP Medium"

finish
