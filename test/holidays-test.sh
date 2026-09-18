#!/usr/bin/env bash
# The Dutch holidays the calendar panel marks, computed in shell/Commons/holidays.js.
#
# Easter is the one to get right -- every moving holiday hangs off it -- so it is checked
# against known dates across the range the algorithm is easiest to get wrong in, and
# Koningsdag against the one year in the next decade it moves.
source "$(dirname "$0")/lib.sh"

require node || finish

holidays() {
  node -e "
    const h = require('$ROOT/shell/Commons/holidays.js');
    const fmt = d => d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0');
    $1"
}

# Easter Sunday, from published tables.
check "Easter lands on the published dates" \
  test "$(holidays "console.log([2019, 2024, 2025, 2026, 2027, 2038].map(y => fmt(h.easter(y))).join(' '))")" \
  = "2019-04-21 2024-03-31 2025-04-20 2026-04-05 2027-03-28 2038-04-25"

check "2026 has the moving holidays in the right places" \
  test "$(holidays "console.log(h.netherlands(2026).map(x => fmt(x.date) + ' ' + x.name).filter(s => /Vrijdag|Hemelvaart|Pinkster/.test(s)).join(', '))")" \
  = "2026-04-03 Goede Vrijdag, 2026-05-14 Hemelvaartsdag, 2026-05-24 Eerste Pinksterdag, 2026-05-25 Tweede Pinksterdag"

check "Koningsdag moves to the 26th when the 27th is a Sunday" \
  test "$(holidays "console.log(fmt(h.netherlands(2025).find(x => x.name == 'Koningsdag').date), fmt(h.netherlands(2026).find(x => x.name == 'Koningsdag').date))")" \
  = "2025-04-26 2026-04-27"

check "coming up runs past the end of the year" \
  test "$(holidays "console.log(h.upcoming(new Date(2026, 11, 26), 2).map(x => x.name).join(', '))")" \
  = "Tweede Kerstdag, Nieuwjaarsdag"

check "a day looks up by its key" \
  test "$(holidays "console.log(h.lookup(2026)[h.key(new Date(2026, 4, 5))])")" = Bevrijdingsdag

finish
