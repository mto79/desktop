#!/usr/bin/env bash
# NCSC-NL's advisories. What matters: the rating is read as the NCSC wrote it, a match means
# a whole word and not a coincidence, and a link from a feed goes nowhere but the NCSC.
source "$(dirname "$0")/lib.sh"

require python3 || finish
require jq || finish

ADVISORIES="$ROOT/bin/desktop-advisories"
sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
export HOME="$sandbox" XDG_CACHE_HOME="$sandbox/cache" XDG_CONFIG_HOME="$sandbox/config"
mkdir -p "$sandbox/bin" "$sandbox/config/desktop/dashboard"

# Only what is stubbed is "installed", so the test does not depend on this machine.
printf '#!/usr/bin/env bash\nprintf "kernel\\nbrotli\\njava-21-openjdk\\nfirewalld\\nredhat-rpm-config\\n"\n' >"$sandbox/bin/rpm"
chmod +x "$sandbox/bin/rpm"
export PATH="$sandbox/bin:/usr/bin:/bin"

now=$(LC_ALL=C date -R)
old=$(LC_ALL=C date -R -d '-30 days')
cat >"$sandbox/feed.xml" <<XML
<?xml version='1.0' encoding='UTF-8'?>
<rss version="2.0"><channel>
<item><title>NCSC-2026-0001 [1.00] [H/H] Kwetsbaarheden verholpen in Linux kernel</title>
  <link>https://advisories.ncsc.nl/advisory?id=NCSC-2026-0001</link>
  <description>Een &lt;b&gt;samenvatting&lt;/b&gt;.</description><pubDate>$now</pubDate></item>
<item><title>NCSC-2026-0002 [1.02] [M/H] Kwetsbaarheid in Google Brotli-decoder</title>
  <link>https://advisories.ncsc.nl/advisory?id=NCSC-2026-0002</link><description>x</description><pubDate>$now</pubDate></item>
<item><title>NCSC-2026-0003 [1.00] [M/H] Meerdere kwetsbaarheden verholpen in Oracle Java</title>
  <link>https://example.org/elsewhere</link><description>x</description><pubDate>$now</pubDate></item>
<item><title>NCSC-2026-0004 [1.00] [H/H] Kwetsbaarheden verholpen in Cisco Secure Firewall ASA</title>
  <link>https://advisories.ncsc.nl/a</link><description>x</description><pubDate>$now</pubDate></item>
<item><title>NCSC-2026-0005 [1.00] [H/H] Kwetsbaarheden verholpen in Red Hat OpenShift door Red Hat</title>
  <link>https://advisories.ncsc.nl/b</link><description>x</description><pubDate>$old</pubDate></item>
<item><title>Not an advisory at all</title><link>https://advisories.ncsc.nl/c</link></item>
</channel></rss>
XML

run() { "$ADVISORIES" --json --from "$sandbox/feed.xml"; }
answer=$(run)
item() { jq -r ".items[] | select(.id == \"NCSC-2026-000$1\") | $2" <<<"$answer"; }

check "a title that is no advisory is passed over" test "$(jq '.items | length' <<<"$answer")" = 5
check "the likelihood is read" test "$(item 1 .likelihood)" = H
check "and the damage" test "$(item 2 .damage)" = H
check "the product is what comes after the NCSC's sentence" test "$(item 1 .product)" = "Linux kernel"
check "with 'Meerdere' as well" test "$(item 3 .product)" = "Oracle Java"
check "and without who fixed it" test "$(item 5 .product)" = "Red Hat OpenShift"
check "markup in a summary is not kept" test "$(item 1 .summary)" = "Een samenvatting."
check "a version past 1.00 is an update" test "$(item 2 .updated)" = true

check "the kernel is yours" test "$(item 1 '.mine[0]')" = kernel
check "a hyphenated product finds its package" test "$(item 2 '.mine[0]')" = brotli
check "Java finds its openjdk" test "$(item 3 '.mine[0]')" = java
check "'Firewall' is not firewalld: whole words" test "$(item 4 '.mine | length')" = 0
check "'Red' and 'Hat' are not redhat-rpm-config" test "$(item 5 '.mine | length')" = 0

check "a link to the NCSC is kept" test -n "$(item 1 .link)"
check "a link anywhere else is not" test -z "$(item 3 .link)"

check "a high/high naming something here puts a dot on the tab" test "$(jq .attention <<<"$answer")" = 1
check "a high/high naming nothing here does not count" test "$(jq .highHigh <<<"$answer")" = 3

echo '{"watch": ["OpenShift"]}' >"$sandbox/config/desktop/dashboard/advisories.json"
answer=$(run)
check "your own list counts" test "$(item 5 '.mine[0]')" = OpenShift
check "but an old one no longer asks for attention" test "$(jq .attention <<<"$answer")" = 1
echo 'not json' >"$sandbox/config/desktop/dashboard/advisories.json"
check "a broken list is no failure" test "$(run | jq .connected)" = true

check "a broken feed says so and does not crash" \
  bash -c "echo '<rss' >'$sandbox/bad.xml'; '$ADVISORIES' --json --from '$sandbox/bad.xml' | jq -e '.connected == false' >/dev/null"

PAGE="$ROOT/shell/Dashboard/SecurityPage.qml"
check "it is a heading of the security tab" grep -q '"advisories": "Advisories"' "$PAGE"
check "and is asked for through desktop-dash" grep -q 'advisories) desktop-advisories --json' "$ROOT/bin/desktop-dash"

finish
