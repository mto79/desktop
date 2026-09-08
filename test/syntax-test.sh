#!/usr/bin/env bash
# Every shell script parses. Cheap, and catches the class of mistake that only shows up
# when the script is finally run -- often months later, from a keybinding.
source "$(dirname "$0")/lib.sh"

bad=()
while IFS= read -r -d '' f; do
  head -1 "$f" | grep -q "bash\|sh$" || continue
  bash -n "$f" 2>/dev/null || bad+=("${f#$ROOT/}")
done < <(find "$ROOT/bin" "$ROOT/install" "$ROOT/migrations" "$ROOT/test" -type f -print0 2>/dev/null)

if ((${#bad[@]} == 0)); then
  pass "every shell script parses"
else
  fail "every shell script parses" "${bad[*]}"
fi
finish
