#!/usr/bin/env bash
# Config files actually parse.
#
# yazi's tokyo-night flavour once failed to parse for months: yazi renamed a key, the old
# spelling failed the whole file, and yazi silently fell back to preset settings on every
# launch. It reads as "my file manager does not match my theme", never as an error.
source "$(dirname "$0")/lib.sh"

require python3 || finish

bad=()
while IFS= read -r -d '' f; do
  python3 -c "import tomllib,sys;tomllib.load(open(sys.argv[1],'rb'))" "$f" 2>/dev/null || bad+=("${f#$ROOT/}")
done < <(find "$ROOT/config" "$ROOT/default" "$ROOT/themes" -name "*.toml" -print0 2>/dev/null)
if ((${#bad[@]} == 0)); then pass "every tracked TOML parses"; else fail "every tracked TOML parses" "${bad[*]}"; fi

bad=()
while IFS= read -r -d '' f; do
  python3 -c "import json,sys;json.load(open(sys.argv[1]))" "$f" 2>/dev/null || bad+=("${f#$ROOT/}")
done < <(find "$ROOT/config" "$ROOT/themes" "$ROOT/.claude" -name "*.json" -print0 2>/dev/null)
if ((${#bad[@]} == 0)); then pass "every tracked JSON parses"; else fail "every tracked JSON parses" "${bad[*]}"; fi

# yazi's filetype rules key off `url` or `mime`; `name` is the spelling it dropped.
bad=$(grep -rln 'name = "' "$ROOT/config/yazi" 2>/dev/null || true)
if [[ -z $bad ]]; then
  pass "no yazi rules use the retired 'name' key"
else
  fail "no yazi rules use the retired 'name' key" "$bad"
fi
finish
