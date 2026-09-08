#!/usr/bin/env bash
# Ghostty is the only terminal. Alacritty and wezterm were removed, and a reference to
# either is a script that will fail on a machine built from this repo today.
source "$(dirname "$0")/lib.sh"

# Live code only. migrations/ names what it rewrites and the skills explain why the
# terminals went, so both legitimately mention them forever.
for term in alacritty wezterm; do
  hits=$(grep -rli "$term" "$ROOT/bin" "$ROOT/config" "$ROOT/default" "$ROOT/shell" \
    "$ROOT/install" "$ROOT/themes" 2>/dev/null || true)
  if [[ -z $hits ]]; then
    pass "nothing references $term"
  else
    fail "nothing references $term" "$(echo "$hits" | sed "s|$ROOT/||" | tr '\n' ' ')"
  fi
done

# Ghostty cannot set a Wayland app id, so a launcher passing --class is silently
# ignored and its window rule never matches.
hits=$(grep -rn -- "--class" "$ROOT/bin" 2>/dev/null || true)
if [[ -z $hits ]]; then
  pass "no launcher passes --class to ghostty"
else
  fail "no launcher passes --class to ghostty" "$(echo "$hits" | sed "s|$ROOT/||" | tr '\n' ' ')"
fi
finish
