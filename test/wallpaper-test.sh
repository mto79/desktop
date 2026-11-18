#!/usr/bin/env bash

# desktop-wallpaper: fill on a screen shaped like the picture, fit on one shaped nothing like
# it -- but only for a picture whose edge is one colour, which then fills the bars.

source "$(dirname "$0")/lib.sh"

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
mkdir -p "$sandbox/stubs"

# Three screens: a laptop, an ultrawide, and a 4K turned on its side (transform 1).
cat >"$sandbox/stubs/hyprctl" <<'STUB'
#!/usr/bin/env bash
echo '[{"name": "eDP-1", "width": 3840, "height": 2400, "transform": 0},
       {"name": "DP-7", "width": 3440, "height": 1440, "transform": 0},
       {"name": "DP-8", "width": 3840, "height": 2160, "transform": 1}]'
STUB
chmod +x "$sandbox/stubs/hyprctl"

# A plain-edged picture, dark all round with something in the middle; and a busy one.
magick -size 1920x1080 xc:'#070101' -fill white -draw 'circle 960,540 960,300' "$sandbox/plain.png"
magick -size 1920x1080 plasma:fractal "$sandbox/photo.png"

plan() { env PATH="$sandbox/stubs:$PATH" DESKTOP_BACKGROUND="$1" bash "$ROOT/bin/desktop-wallpaper" --plan; }

out=$(plan "$sandbox/plain.png")
check "a screen shaped near the picture is filled" grep -qx $'eDP-1\t3840x2400\tfill' <<<"$out"
check "an ultrawide is fitted, not cropped" grep -qx $'DP-7\t3440x1440\tfit' <<<"$out"
check "a screen turned on its side counts as portrait, and is fitted" grep -qx $'DP-8\t2160x3840\tfit' <<<"$out"
check "a photograph is filled everywhere: no bars around it" \
  test "$(plan "$sandbox/photo.png" | cut -f3 | sort -u)" = fill
check "every start goes through it, none straight to swaybg" \
  test -z "$(grep -rln 'swaybg -i' "$ROOT/bin" "$ROOT/default")"
check "and a screen plugged in starts it again" grep -q 'WALLPAPER = "desktop-wallpaper"' "$ROOT/bin/desktop-monitors-watch"

finish
