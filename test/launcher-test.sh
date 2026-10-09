#!/usr/bin/env bash
# The launcher's modes. The calculator is the one with something to get wrong: it turns
# what was typed into an answer by evaluating it, so what it will evaluate has to be
# arithmetic and nothing else.
source "$(dirname "$0")/lib.sh"

LAUNCHER="$ROOT/shell/Launcher/Launcher.qml"

if require node; then
  calc() { node -e "const c = require('$ROOT/shell/Commons/calc.js'); console.log(String(c.calculate(process.argv[1])))" "$1"; }

  check "a sum has an answer" test "$(calc '6*7')" = 42
  check "brackets and precedence are arithmetic's" test "$(calc '(2 + 3) * 4 - 6 / 2')" = 17
  check "^ is a power" test "$(calc '2^10')" = 1024
  check "a decimal comma is a decimal point" test "$(calc '0,5 * 4')" = 2
  check "and float noise is not shown" test "$(calc '0,1+0,2')" = 0.3
  check "the named functions work" test "$(calc 'sqrt(16) + abs(-2)')" = 6
  check "a comma between arguments stays one" test "$(calc 'max(3, 7)')" = 7
  check "pi is known" test "$(calc 'round(pi * 100)')" = 314

  # Everything below must have no answer, and must not be run to find that out.
  marker=$(mktemp -u)
  for attempt in \
    "require('fs').writeFileSync('$marker', 'x')" \
    "process.exit(3)" \
    "1; 2" \
    "constructor" \
    "constructor.constructor('return 1')()" \
    "this" \
    '"a" + "b"' \
    "[1,2].length" \
    "a = 1" \
    "rm -rf /"; do
    check "not a sum, so no answer: $attempt" test "$(calc "$attempt")" = null
  done
  check "and nothing in those was executed" test ! -e "$marker"

  check "half a sum has no answer yet" test "$(calc '(2 + 3')" = null
  check "nor does dividing by zero" test "$(calc '1/0')" = null
  check "nor nothing at all" test "$(calc '   ')" = null
fi

# --- the emoji list
emoji=$("$ROOT/bin/desktop-emoji-list")
check "the emoji list has names to search" grep -qP '^🚀\trocket$' <<<"$emoji"
check "one emoji a line, and its name" test "$(grep -cvP '^[^\t]+\t[a-z0-9 -]+$' <<<"$emoji")" = 0
check "skin tones are not emoji on their own" lacks 'fitzpatrick' <<<"$emoji"
check "the symbols from the older blocks ask for their emoji form" \
  grep -qP "^☀\x{FE0F}\t" <<<"$emoji"

# --- the modes
# A prefix has to be a character no application's name begins with, or typing that name
# lands in the mode instead.
prefixes=$(grep -oP '^\s+prefix: "\K[^"]+' "$LAUNCHER" | tr -d '\n')
check "the modes are behind symbols, not letters" test -z "$(tr -d '=>/:' <<<"$prefixes")"
check "there are four of them" test "${#prefixes}" = 4
check "? lists them" grep -q 'if (first === "?")' "$LAUNCHER"
check "a mode is never entered while a menu is being chosen from" \
  grep -q 'if (selecting || query === "")' "$LAUNCHER"
check "the sum is worked out by the tested code" grep -q 'return Calc.calculate(text);' "$LAUNCHER"
check "what is copied is passed as an argument, not through a shell" \
  grep -q 'execDetached(\["wl-copy", "--", item.payload\])' "$LAUNCHER"

finish
