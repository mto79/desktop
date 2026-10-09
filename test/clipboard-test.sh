#!/usr/bin/env bash
# Clipboard history is a list of everything copied, kept on disk. The one thing it must
# never keep is what a password manager copied, and the one thing it must get right is
# handing back the entry that was chosen and not its neighbour.
#
# cliphist, wl-paste, wl-copy and the launcher's list are stubs. Nothing here touches the
# clipboard of the machine the suite runs on.
source "$(dirname "$0")/lib.sh"

CLIP="$ROOT/bin/desktop-clipboard"
sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
stubs="$sandbox/stubs"
mkdir -p "$stubs"

cat >"$stubs/wl-paste" <<STUB
#!/usr/bin/env bash
[[ \$1 == --list-types ]] || exit 0
[[ -f "$sandbox/types" ]] || exit 1
cat "$sandbox/types"
STUB
# store appends what it was given; list and decode answer from two fixed files.
cat >"$stubs/cliphist" <<STUB
#!/usr/bin/env bash
case "\$1" in
store) cat >>"$sandbox/stored"; echo >>"$sandbox/stored" ;;
list) cat "$sandbox/list" 2>/dev/null ;;
decode) if [[ \$2 == 7 && -f "$sandbox/picture.png" ]]; then cat "$sandbox/picture.png"; else echo "decoded-\$2"; fi ;;
delete) cat >"$sandbox/deleted" ;;
wipe) : >"$sandbox/wiped" ;;
esac
STUB
printf '#!/usr/bin/env bash\ncat >"%s/copied"\n' "$sandbox" >"$stubs/wl-copy"
# The launcher: remembers what it was offered, and "chooses" the line in \$CHOICE.
cat >"$stubs/desktop-menu-select" <<STUB
#!/usr/bin/env bash
cat >"$sandbox/offered"
[[ -n \${CHOICE:-} ]] || exit 1
printf '%s\n' "\$CHOICE"
STUB
printf '#!/usr/bin/env bash\necho "$*" >>"%s/notified"\n' "$sandbox" >"$stubs/notify-send"
chmod +x "$stubs"/*
# A runtime directory of its own: thumbnails are kept there, and must not land in the real one.
run() { PATH="$stubs:$PATH" XDG_RUNTIME_DIR="$sandbox/run" bash "$CLIP" "$@"; }

# --- what is kept
printf 'text/plain\nUTF8_STRING\n' >"$sandbox/types"
printf 'an ordinary copy' | run store
check "an ordinary copy is kept" grep -qx 'an ordinary copy' "$sandbox/stored"

printf 'text/plain\nx-kde-passwordManagerHint\n' >"$sandbox/types"
printf 'hunter2' | run store
check "what a password manager copied is not" lacks 'hunter2' "$sandbox/stored"

rm "$sandbox/types"
printf 'who-knows' | run store
check "nor anything whose source cannot be asked" lacks 'who-knows' "$sandbox/stored"

# --- choosing
printf '7\t[[ binary data 14 KiB png 640x480 ]]\n6\tkubectl get pods -A\n5\tkubectl get pods -n prod\n4\twith\ta tab\n' >"$sandbox/list"
CHOICE='kubectl get pods -n prod' run pick
check "the list shows the text, not cliphist's ids" lacks -E '^[0-9]+	' "$sandbox/offered"
check "an image reads as one" grep -q 'Image 640x480	png · 14 KiB' "$sandbox/offered"
check "the entry chosen is the one put on the clipboard" test "$(cat "$sandbox/copied")" = decoded-5
CHOICE='Image 640x480	png · 14 KiB' run pick
check "an image can be chosen too" test "$(cat "$sandbox/copied")" = decoded-7
CHOICE='with a tab' run pick
check "a tab in the text does not break the line it is on" test "$(cat "$sandbox/copied")" = decoded-4

rm -f "$sandbox/copied"
run pick
check "choosing nothing copies nothing" test ! -e "$sandbox/copied"

: >"$sandbox/list"
run pick
check "an empty history says so instead of opening an empty list" grep -q 'empty' "$sandbox/notified"

# --- pictures
# "Image 640x480" names six screenshots the same; the list shows the picture instead.
printf '7\t[[ binary data 14 KiB png 640x480 ]]\n6\tkubectl get pods -A\n' >"$sandbox/list"
if have magick; then
  magick -size 64x48 xc:red "png:$sandbox/picture.png"
  CHOICE='kubectl get pods -A' run pick
  thumb="$sandbox/run/desktop/clipboard/7.png"
  check "an image is offered as a picture of itself" grep -q "^$thumb	Image 640x480" "$sandbox/offered"
  check "which is a small copy, made once" test -s "$thumb"
  check "in a directory nobody else can read" test "$(stat -c %a "$sandbox/run/desktop/clipboard")" = 700
  CHOICE='Image 640x480	png · 14 KiB' run pick
  check "and choosing it still copies the image, not the small copy" \
    cmp -s "$sandbox/copied" "$sandbox/picture.png"
  printf '6\tkubectl get pods -A\n' >"$sandbox/list"
  CHOICE='kubectl get pods -A' run pick
  check "a picture goes when its entry has left the history" test ! -e "$thumb"
  rm -f "$sandbox/picture.png"
else
  pass "skipped the picture checks, magick not installed"
fi
printf '7\t[[ binary data 14 KiB png 640x480 ]]\n' >"$sandbox/list"
CHOICE='Image 640x480	png · 14 KiB' run pick
check "an image that cannot be drawn small is still listed, with a glyph" \
  grep -q '^󰋩	Image 640x480' "$sandbox/offered"

# --- forgetting one
printf '7\t[[ binary data 14 KiB png 640x480 ]]\n6\tkubectl get pods -A\n5\ta token that should not be here\n' >"$sandbox/list"
rm -f "$sandbox/copied"
CHOICE='a token that should not be here' run delete
check "delete hands cliphist the entry that was chosen" \
  test "$(cat "$sandbox/deleted")" = "5	a token that should not be here"
check "and puts nothing on the clipboard" test ! -e "$sandbox/copied"
rm -f "$sandbox/deleted"
run delete
check "choosing nothing forgets nothing" test ! -e "$sandbox/deleted"
check "SUPER + SHIFT + V is the key for it" \
  grep -qx 'bindd = SUPER SHIFT, V, Forget a clipboard entry, exec, desktop-clipboard delete' "$ROOT/config/hypr/bindings.conf"

run clear
check "clear forgets all of it" test -e "$sandbox/wiped"
check "pictures included" test ! -d "$sandbox/run/desktop/clipboard"

# --- wired in
check "the watcher starts at login" \
  grep -qx 'exec-once = uwsm app -- desktop-clipboard watch' "$ROOT/default/hypr/autostart.conf"
check "in the Lua config too" grep -q 'desktop-clipboard watch' "$ROOT/default/hypr/autostart.lua"
check "text and images are watched apart" \
  test "$(grep -c 'wl-paste --type \(text\|image\) --watch' "$CLIP")" = 2
# SUPER + V is unbound from "toggle floating" in the same file; the binding has to come
# after that line or the unbind takes it away again.
check "SUPER + V opens it, after the unbind that frees the key" \
  test "$(grep -n -e '^unbind = SUPER, V$' -e 'desktop-clipboard pick$' "$ROOT/config/hypr/bindings.conf" | cut -d: -f2 | cut -c1-6 | tr '\n' ' ')" = "unbind bindd  "
check "cliphist is installed with the desktop" grep -qxF cliphist "$ROOT/install/desktop-base.packages"

finish
