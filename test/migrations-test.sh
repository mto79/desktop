#!/usr/bin/env bash
# desktop-migrate runs each migration once and remembers it. The failure worth guarding
# is the empty directory: an unmatched glob expands to itself, so the runner would hand
# bash the literal "*.sh", get 127 back, and treat a directory with nothing in it as a
# migration that had just failed.
source "$(dirname "$0")/lib.sh"

MIGRATE="$ROOT/bin/desktop-migrate"

# A sandboxed HOME moves both paths the runner uses -- the migrations it reads and the
# state it writes -- so this never touches the real machine's record of what has run.
sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
migrations="$sandbox/.local/share/desktop/migrations"
state="$sandbox/.local/state/desktop/migrations"
mkdir -p "$migrations"

# Asserting on the state directory alone would prove nothing: the unfixed runner also
# leaves it empty, because the phantom migration "fails" and the runner exits before
# recording anything. The visible symptoms are the non-zero exit and the announcement
# of a migration named "*", so check for those.
out=$(HOME="$sandbox" bash "$MIGRATE" 2>&1 </dev/null); rc=$?
leftover=$(ls -A "$state" 2>/dev/null | grep -v '^skipped$')
if ((rc == 0)) && ! grep -q 'Running migration' <<<"$out" && [[ -z $leftover ]]; then
  pass "an empty migrations directory runs nothing and succeeds"
else
  fail "an empty migrations directory runs nothing and succeeds" \
    "exit $rc, recorded '$leftover' -- the glob went unmatched, needs shopt -s nullglob"
fi

# The other half: with nullglob on, a real migration still has to run and be recorded.
printf '#!/usr/bin/env bash\necho ran\n' > "$migrations/1000000000.sh"
HOME="$sandbox" bash "$MIGRATE" >/dev/null 2>&1
check "a migration that succeeds is recorded" test -f "$state/1000000000.sh"

# And is not run a second time. Nothing enforces idempotency in a migration itself, so
# the runner's memory is the only thing standing between one and every desktop-update.
printf '#!/usr/bin/env bash\nexit 1\n' > "$migrations/1000000000.sh"
if HOME="$sandbox" bash "$MIGRATE" >/dev/null 2>&1; then
  pass "a recorded migration does not run again"
else
  fail "a recorded migration does not run again" "it re-ran and this time it failed"
fi
finish
