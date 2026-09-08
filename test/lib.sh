#!/usr/bin/env bash

# Shared helpers. Source this from a test; running it directly is a mistake.
#
# Output is TAP-ish -- "ok - what held" and "not ok - what did not" -- so a failure
# reads as a sentence rather than a diff of two variables.

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  echo "source test/lib.sh from a test; do not run it directly" >&2
  exit 1
fi

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
export ROOT

FAILURES=0

pass() { printf 'ok - %s\n' "$1"; }

# Does not exit: a test file reports everything it found rather than stopping at the
# first problem, which is what makes a run worth reading.
fail() {
  local what="$1" detail="${2:-}"
  printf 'not ok - %s\n' "$what" >&2
  [[ -n $detail ]] && printf '      %s\n' "$detail" >&2
  FAILURES=$((FAILURES + 1))
}

check() {
  local what="$1"; shift
  if "$@"; then pass "$what"; else fail "$what"; fi
}

# Call at the end of every test file.
finish() {
  ((FAILURES == 0)) && exit 0
  printf '\n%d check(s) failed in %s\n' "$FAILURES" "$(basename "$0")" >&2
  exit 1
}

have() { command -v "$1" >/dev/null 2>&1; }

# Skip rather than fail when the tool a check needs is absent: these run on machines
# mid-install as often as on finished ones.
require() {
  local cmd="$1"
  have "$cmd" && return 0
  pass "skipped, $cmd not installed"
  return 1
}

# A live Hyprland, not merely the variable. A session can leave a stale socket behind.
compositor_reachable() {
  [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] || return 1
  have hyprctl || return 1
  timeout 2 hyprctl version >/dev/null 2>&1
}
