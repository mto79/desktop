#!/usr/bin/env bash
# The screensaver's logo is a copy the user may edit, made once at install. A redrawn
# logo therefore reaches an installed machine only through a migration, and the failure
# worth guarding is that migration flattening a drawing somebody made themselves.
source "$(dirname "$0")/lib.sh"

MIGRATION="$ROOT/migrations/1791509635.sh"

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
screensaver="$sandbox/.config/desktop/branding/screensaver.txt"
mkdir -p "$sandbox/.local/share/desktop" "$(dirname "$screensaver")"
cp "$ROOT/logo.txt" "$sandbox/.local/share/desktop/logo.txt"

# The logo as it shipped before the redraw. Encoded because its first line ends in two
# spaces, which an editor would strip from a heredoc and so change what is being matched.
old_logo() {
  base64 -d <<<"ICDilojilojilojiloQg4paE4paI4paI4paI4paT4paE4paE4paE4paI4paI4paI4paI4paI4paTIOKWkuKWiOKWiOKWiOKWiOKWiCAgCiAg4paT4paI4paI4paS4paA4paI4paAIOKWiOKWiOKWkuKWkyAg4paI4paI4paSIOKWk+KWkuKWkuKWiOKWiOKWkiAg4paI4paI4paSCiAg4paT4paI4paIICAgIOKWk+KWiOKWiOKWkeKWkiDilpPilojilojilpEg4paS4paR4paS4paI4paI4paRICDilojilojilpIKICDilpLilojiloggICAg4paS4paI4paIIOKWkSDilpPilojilojilpMg4paRIOKWkuKWiOKWiCAgIOKWiOKWiOKWkQogIOKWkuKWiOKWiOKWkiAgIOKWkeKWiOKWiOKWkiAg4paS4paI4paI4paSIOKWkSDilpEg4paI4paI4paI4paI4paT4paS4paRCg=="
}

check "a machine without screensaver branding is not an error" \
  env HOME="$sandbox" bash "$MIGRATION"

old_logo >"$screensaver"
HOME="$sandbox" bash "$MIGRATION" >/dev/null
check "an untouched copy of the old logo becomes the new one" \
  cmp -s "$ROOT/logo.txt" "$screensaver"

HOME="$sandbox" bash "$MIGRATION" >/dev/null
check "running it again changes nothing" cmp -s "$ROOT/logo.txt" "$screensaver"

printf 'my own drawing\n' >"$screensaver"
HOME="$sandbox" bash "$MIGRATION" >/dev/null
check "branding that was edited by hand is left alone" \
  grep -qx 'my own drawing' "$screensaver"

# tte centres the block it is given, so an indent baked into the logo shifts it off
# centre, and trailing spaces are what made the old copy awkward to match.
if grep -qE '^ +[^ ]' "$ROOT/logo.txt" && ! grep -qE '^[^ ]' "$ROOT/logo.txt"; then
  fail "the logo carries no indent of its own" "every line starts with a space"
else
  pass "the logo carries no indent of its own"
fi
if grep -qE ' $' "$ROOT/logo.txt"; then
  fail "the logo has no trailing spaces"
else
  pass "the logo has no trailing spaces"
fi
finish
