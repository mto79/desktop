#!/usr/bin/env bash
# The dashboard's tabs: one subject, one answer in JSON, and a page that draws it.
#
# What is checked is the promise each answer makes about itself -- "connected": true is
# your data, false is invented and says so -- because a dashboard that shows a plausible
# number it made up is worse than an empty one. The network, oc, the secret service and
# Home Assistant are all stubs.
source "$(dirname "$0")/lib.sh"

require jq || finish

DASH="$ROOT/bin/desktop-dash"
PAGES="$ROOT/shell/Dashboard"
sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
stubs="$sandbox/stubs"
mkdir -p "$stubs" "$sandbox/config/desktop/dashboard" "$sandbox/state/desktop/dashboard"

run() {
  PATH="$stubs:$PATH" XDG_CONFIG_HOME="$sandbox/config" XDG_STATE_HOME="$sandbox/state" \
    XDG_CACHE_HOME="$sandbox/cache" bash "$DASH" "$@"
}

# --- every tab answers, and says how real the answer is
for tab in home health finance infra; do
  answer=$(run "$tab" --sample)
  check "the $tab sample says it is not your data" test "$(jq -r .connected <<<"$answer")" = false
  check "and says what would make it real" test "$(jq -r '.how | length' <<<"$answer")" -ge 1
done

# --- health and finance are files you keep
answer=$(run health --json)
check "with no file of yours, health is sample data" test "$(jq -r .connected <<<"$answer")" = false
echo '{"week":{"distance_km":12,"hours":1,"activities":1,"goal_km":40},"days":[],"body":{},"recent":[]}' \
  >"$sandbox/state/desktop/dashboard/health.json"
answer=$(run health --json)
check "with one, it is yours" test "$(jq -r '"\(.connected) \(.week.distance_km)"' <<<"$answer")" = "true 12"
check "and nothing of the sample is mixed into it" test "$(jq -r '.how // "none"' <<<"$answer")" = none
echo 'not json at all' >"$sandbox/state/desktop/dashboard/finance.json"
check "a file that cannot be read is not shown as yours" \
  test "$(run finance --json | jq -r .connected)" = false
check "nothing here logs in to a bank or to Strava" lacks -iE 'strava\.com|garmin\.com|oauth|iban' "$DASH"

# --- watching
cat >"$stubs/curl" <<'STUB'
#!/usr/bin/env bash
url="${*: -1}"
case "$url" in
*api.github.com/repos/acme/ahead/*) echo '{"tag_name":"v2.0.0"}' ;;
*api.github.com/repos/acme/same/*) echo '{"tag_name":"v1.4.2"}' ;;
*registry.npmjs.org/*) echo '{"version":"3.1.0"}' ;;
*pypi.org/*) echo '{"info":{"version":"0.9.0"}}' ;;
*mirror.openshift.com/*) printf 'Name:           4.22.17\n' ;;
*) exit 22 ;;
esac
STUB
chmod +x "$stubs/curl"
cat >"$sandbox/config/desktop/dashboard/watch.list" <<'LIST'
# name | where the newest is published | how to ask what is installed
Ahead|github:acme/ahead|echo "ahead version 1.9.3"
Same|github:acme/same|echo "v1.4.2-1.fc44"
Node thing|npm:thing|echo 3.1.0
Not here|pypi:missing|false
Unreachable|github:acme/gone|echo 1.0
Client|ocp:stable-4.22|echo "Client Version: 4.22.16"
LIST
answer=$(run watch --json)
state() { jq -r --arg n "$1" '.items[] | select(.name == $n) | .state' <<<"$answer"; }
check "something with a newer version out is behind" test "$(state Ahead)" = behind
check "the version is read out of whatever is written round it" test "$(state Same)" = current
check "npm is asked too" test "$(state "Node thing")" = current
check "what is not installed is said to be absent" test "$(state "Not here")" = absent
check "what could not be asked is unknown, not current" test "$(state Unreachable)" = unknown
check "a release channel counts as a source" test "$(state Client)" = behind
check "what is behind is counted, and listed first" \
  test "$(jq -r '"\(.behind) \(.items[0].state)"' <<<"$answer")" = "2 behind"
: >"$sandbox/urls"
printf '#!/usr/bin/env bash\necho asked >>"%s/urls"\nexit 22\n' "$sandbox" >"$stubs/curl"
run watch --json >/dev/null
check "the answer is kept, so the network is not asked every time the tab is opened" test ! -s "$sandbox/urls"

# --- infrastructure
cat >"$stubs/oc" <<'STUB'
#!/usr/bin/env bash
ctx=""; for ((i = 1; i <= $#; i++)); do [[ ${!i} == --context ]] && { j=$((i + 1)); ctx=${!j}; }; done
case " $* " in
*" whoami "*) [[ $ctx == ocp202 || $ctx == ocp204 ]] ;;
*" clusterversion "*) echo '{"status":{"desired":{"version":"4.22.16"},"conditions":[{"type":"Progressing","status":"False"}]}}' ;;
*" nodes "*)
  if [[ $ctx == ocp204 ]]; then
    echo '{"items":[{"status":{"conditions":[{"type":"Ready","status":"True"}]}},{"status":{"conditions":[{"type":"Ready","status":"False"}]}}]}'
  else
    echo '{"items":[{"status":{"conditions":[{"type":"Ready","status":"True"}]}}]}'
  fi ;;
esac
STUB
printf '#!/usr/bin/env bash\nOCL_NAMES=(ocp202 ocp203 ocp204)\n' >"$stubs/ocl"
chmod +x "$stubs/oc" "$stubs/ocl"
answer=$(run infra --json)
cluster() { jq -r --arg n "$1" '.clusters[] | select(.name == $n) | .state' <<<"$answer"; }
check "the clusters are the ones ocl lists" test "$(jq -r '.clusters | length' <<<"$answer")" = 3
check "one with every node ready is healthy" test "$(cluster ocp202)" = healthy
check "one with a node that is not is degraded" test "$(cluster ocp204)" = degraded
check "one there is no token for is signed out, not broken" test "$(cluster ocp203)" = signed-out
check "trouble is counted" test "$(jq -r '"\(.signed_in) \(.trouble)"' <<<"$answer")" = "2 1"

# --- home
check "with nothing configured, the house is sample data" test "$(run home --json | jq -r .connected)" = false
cat >"$sandbox/config/desktop/dashboard/home.conf" <<'CONF'
url = https://home.example:8123
sensor.living | Living room | climate
light.kitchen | Kitchen | light
sensor.gone | Attic | climate
CONF
printf '#!/usr/bin/env bash\necho the-token\n' >"$stubs/secret-tool"
cat >"$stubs/curl" <<STUB
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$sandbox/ha-call"
echo '[{"entity_id":"sensor.living","state":"20.5","attributes":{"unit_of_measurement":"°C"}},{"entity_id":"light.kitchen","state":"on","attributes":{}}]'
STUB
chmod +x "$stubs/secret-tool" "$stubs/curl"
answer=$(run home --json)
check "configured, the house is asked of Home Assistant" grep -q 'https://home.example:8123/api/states' "$sandbox/ha-call"
check "with the token from the secret service, not from a file" grep -q 'Authorization: Bearer the-token' "$sandbox/ha-call"
check "and what comes back is yours" \
  test "$(jq -r '"\(.connected) \(.rooms[0].label) \(.rooms[0].value)\(.rooms[0].unit)"' <<<"$answer")" = "true Living room 20.5°C"
check "something Home Assistant does not know is shown as unavailable" \
  test "$(jq -r '.rooms[] | select(.label == "Attic") | .value' <<<"$answer")" = unavailable
check "the token is only ever asked of the secret service" \
  test "$(grep -c 'token=\$(secret homeassistant)' "$DASH")" = 1

# --- news
cat >"$sandbox/config/desktop/dashboard/news.list" <<LIST
Tweakers|https://tweakers.net|https://feeds.test/rss

[world]
Atom site|https://atom.test|https://feeds.test/atom
Gone|https://gone.test|https://feeds.test/missing
Local file|https://x.test|file:///etc/passwd
LIST
mkdir -p "$sandbox/py"
# The reader fetches with urllib, so the network is replaced at that level.
cat >"$sandbox/py/sitecustomize.py" <<'PY'
import io, urllib.request, urllib.error
RSS = b"""<rss><channel>
<item><title>Kernel 7.3 &amp; &lt;b&gt;more&lt;/b&gt;</title><link>https://tweakers.net/a</link><pubDate>Mon, 12 Oct 2026 00:00:00 +0000</pubDate></item>
<item><title>Evil</title><link>javascript:alert(1)</link></item>
<item><title>Second</title><link>https://tweakers.net/b</link></item></channel></rss>"""
ATOM = b"""<feed xmlns="http://www.w3.org/2005/Atom">
<entry><title>An Atom entry</title><link href="https://atom.test/1"/><updated>2026-10-12T00:00:00Z</updated></entry></feed>"""
FEEDS = {"https://feeds.test/rss": RSS, "https://feeds.test/atom": ATOM}
def fake(request, timeout=None):
    url = request.full_url if hasattr(request, "full_url") else request
    if url not in FEEDS:
        raise urllib.error.URLError("no such feed in this test")
    return io.BytesIO(FEEDS[url])
urllib.request.urlopen = fake
PY
# Through desktop-dash itself, so the headings in the list are read the way they are for real.
mkdir -p "$sandbox/pybin"
printf '#!/usr/bin/env bash\nPYTHONPATH="%s/py" exec python3 "%s/bin/desktop-dash-news"\n' "$sandbox" "$ROOT" >"$sandbox/pybin/desktop-dash-news"
chmod +x "$sandbox/pybin/desktop-dash-news"
news=$(PATH="$sandbox/pybin:$stubs:$PATH" XDG_CONFIG_HOME="$sandbox/config" XDG_STATE_HOME="$sandbox/state" XDG_CACHE_HOME="$sandbox/newscache" bash "$DASH" news --json)
feed() { jq -r --arg n "$1" ".feeds[] | select(.name == \$n) | $2" <<<"$news"; }
check "a site keeps the heading it was listed under" test "$(feed Tweakers '.category')" = tech
check "an RSS feed is read" test "$(feed Tweakers '.items[0].link')" = "https://tweakers.net/a"
check "a headline is text, without the markup it came in" test "$(feed Tweakers '.items[0].title')" = "Kernel 7.3 & more"
check "and has a time" test "$(feed Tweakers '.items[0].at')" -gt 1700000000
check "a link that is not a web address is left out" test "$(feed Tweakers '[.items[].title] | join(",")')" = "Kernel 7.3 & more,Second"
check "an Atom feed is read too" test "$(feed 'Atom site' '.items[0].link')" = "https://atom.test/1"
check "a site that does not answer is a feed that says so, not a missing one" test "$(feed Gone '.ok')" = false
check "a feed is only ever fetched over the web" test "$(feed 'Local file' '.items | length')" = 0
check "the page hands a headline to the browser as an argument" \
  grep -q 'execDetached(\["xdg-open", link\])' "$PAGES/NewsPage.qml"
check "a site under another heading belongs to it" test "$(feed 'Atom site' '.category')" = world
defaults=$(sed -n '/^default_news()/,/^LIST$/p' "$DASH")
check "technology leads with Tweakers, and has five more" \
  test "$(sed -n '/^\[tech\]/,/^$/p' <<<"$defaults" | grep '|' | cut -d'|' -f1 | head -1) $(sed -n '/^\[tech\]/,/^$/p' <<<"$defaults" | grep -c '|')" = "Tweakers 6"
check "the world is a heading of its own" test "$(sed -n '/^\[world\]/,/^LIST$/p' <<<"$defaults" | grep -c '|')" -ge 5
# A page of news that runs off the bottom is one where the last site is never read.
check "the news page fits the room it is given, every row of it" \
  grep -q 'var each = (room - used - Style.overviewSpacing \* (rows - 1)) / rows;' "$PAGES/NewsPage.qml"
# Scrolling that had to be discovered -- drag the list, with only a fade to say there was
# more -- was scrolling nobody used. A card now shows where you are and takes the wheel.
CARD="$PAGES/Card.qml"
check "a card with more than it shows takes the wheel, and only then" \
  test -n "$(sed -n '/^  WheelHandler {/,/^  }/p' "$CARD" | grep 'enabled: card.scrollable')"
check "it has a bar that shows how far through it you are" grep -q 'id: thumb' "$CARD"
check "which can be dragged" test -n "$(sed -n '/id: grip/,/^    }/p' "$CARD" | grep 'card.scrollTo')"
check "and arrows to move a card's worth, up as well as down" \
  test "$(grep -c 'onChosen: card.scrollBy' "$CARD")" = 2
# Dragging the list fought the page behind it for the same gesture.
check "the list itself is not dragged" grep -q 'interactive: false' "$CARD"
check "scrolling never runs past either end" \
  grep -q 'view.contentY = Math.max(0, Math.min(card.furthest, position));' "$CARD"

# --- the voice, drawn
ORB="$ROOT/shell/Ui/Orb.qml"
check "the voice is drawn as a network: nodes, connections, and signals along them" \
  test "$(grep -c -e 'readonly property var nodes' -e 'readonly property var links' -e 'sparks.push' "$ORB")" = 3
check "signals run inwards while it listens and outwards while it speaks" \
  grep -q 'var place = orb.listening ? 1 - along : along;' "$ORB"
# The same face every day: where the nodes sit is worked out, not drawn at random.
check "the network is the same one every time" lacks 'Math.random' "$ORB"
# It repaints many times a second, which is only worth doing where it can be seen.
check "and is only animated where somebody can see it" \
  test -n "$(sed -n '/^  Timer {/,/^  }/p' "$ORB" | grep 'running: orb.running && orb.visible')"
check "the dashboard stops it when its workspace is not in front" \
  grep -q 'running: root.lookedAt && root.shown' "$PAGES/Dashboard.qml"
check "the house is called Domotics on its tab" grep -q 'label: "Domotics"' "$PAGES/Dashboard.qml"

# --- the pages
frame="$PAGES/Dashboard.qml"
for tab in $(bash "$DASH" tabs); do
  check "the $tab tab is on the dashboard" grep -q "key: \"$tab\"" "$frame"
done
check "there is a page for each" \
  test "$(grep -cE '^            (Start|Home|Infra|Health|Finance|Watch|News)Page \{' "$frame")" = "$(bash "$DASH" tabs | wc -l)"
for page in Home Infra Health Finance Watch News; do
  check "the $page page says so when its numbers are invented" grep -q '^  Unconnected {' "$PAGES/${page}Page.qml"
done
# `data` is the property an Item keeps its children in; a page with one of its own of that
# name loads, and then draws nothing.
check "no page calls its answer 'data'" lacks -E '^\s+property var data\b' "$PAGES"/*.qml
# `top` and its like are anchors on every Item, and final: a property of that name fails
# the file to load, and the whole shell with it.
check "nothing on the dashboard takes the name of an anchor" \
  lacks -E '^\s+(readonly )?property [A-Za-z<>]+ (left|right|top|bottom|baseline):' "$PAGES"/*.qml "$ROOT/shell/Ui/Orb.qml"
# The voice sits above the tabs, so it is on every one of them.
check "the voice is on every tab" \
  test "$(grep -n -e '^            Orb {' -e '// --- the tabs ---' "$frame" | head -1 | grep -c 'Orb {')" = 1
check "a tab can be asked for by name" grep -q 'function dashboardTab(key: string): string' "$ROOT/shell/shell.qml"

finish
