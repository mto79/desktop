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
  test "$(grep -cE '^            (Start|Ai|Home|Infra|Health|Finance|Watch|News)Page \{' "$frame")" = "$(bash "$DASH" tabs | wc -l)"
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

# --- the AI tab: what you asked the coding agents
PROMPTS="$ROOT/bin/desktop-dash-prompts"
home=$(mktemp -d)
mkdir -p "$home/.claude" "$home/.codex" "$home/.local/share/opencode/storage/"{message/ses_1,part/msg_1,part/msg_2,session/p}
now=$(date +%s)
printf '%s\n' "{\"display\":\"fix the   runner\",\"timestamp\":\"$((now - 60))000\",\"project\":\"/src/desktop\"}" \
  "{\"display\":\"older one\",\"timestamp\":\"$((now - 3 * 86400))000\",\"project\":\"/src/wiki\"}" \
  'not json at all' >"$home/.claude/history.jsonl"
printf '%s\n' "{\"session_id\":\"s\",\"ts\":$((now - 120)),\"text\":\"why does it crash\"}" >"$home/.codex/history.jsonl"
printf '{"id":"ses_1","directory":"/src/infra"}' >"$home/.local/share/opencode/storage/session/p/ses_1.json"
printf '{"id":"msg_1","sessionID":"ses_1","role":"user","time":{"created":%s000},"model":{"modelID":"Big/Model"}}' "$((now - 30))" >"$home/.local/share/opencode/storage/message/ses_1/msg_1.json"
printf '{"type":"text","text":"build the inventory"}' >"$home/.local/share/opencode/storage/part/msg_1/a.json"
printf '{"type":"text","synthetic":true,"text":"<file>secret contents</file>"}' >"$home/.local/share/opencode/storage/part/msg_1/b.json"
printf '{"id":"msg_2","sessionID":"ses_1","role":"assistant","time":{"created":%s000}}' "$now" >"$home/.local/share/opencode/storage/message/ses_1/msg_2.json"
printf '{"type":"text","text":"an answer, not a prompt"}' >"$home/.local/share/opencode/storage/part/msg_2/a.json"
asked=$(HOME="$home" XDG_DATA_HOME="$home/.local/share" CLAUDE_CONFIG_DIR="$home/.claude" CODEX_HOME="$home/.codex" python3 "$PROMPTS")
of() { jq -r "$1" <<<"$asked"; }
check "what was typed to Claude Code is read, tidied" test "$(of '.agents[] | select(.key == "claude") | .prompts[0] | "\(.text)|\(.project)"')" = "fix the runner|desktop"
check "and to Codex" test "$(of '.agents[] | select(.key == "codex") | .prompts[0].text')" = "why does it crash"
check "and to opencode, with the model it went to" test "$(of '.agents[] | select(.key == "opencode") | .prompts[0] | "\(.text)|\(.project)|\(.model)"')" = "build the inventory|infra|Big/Model"
check "only what you typed: not an answer, not a file an agent attached" lacks -E 'an answer|secret contents' <<<"$asked"
check "a line that cannot be read is passed over" test "$(of '.agents[] | select(.key == "claude") | .total')" = 2
check "today and the week are counted" test "$(of '"\(.today) \(.week)"')" = "3 4"
empty=$(mktemp -d)
check "an agent that is not installed has no prompts, and is no error" \
  test "$(HOME="$empty" XDG_DATA_HOME="$empty/x" CLAUDE_CONFIG_DIR="$empty/c" CODEX_HOME="$empty/d" python3 "$PROMPTS" | jq -r '"\(.connected) \(.total)"')" = "true 0"
rm -rf "$home" "$empty"
check "the reader only reads" lacks -E "open\([^)]*['\"][wa]|requests|urllib|socket" "$PROMPTS"
check "the AI tab stands beside Start" test "$("$DASH" tabs | sed -n 2p)" = ai
AIPAGE="$PAGES/AiPage.qml"
check "it has the voice large, the agents, the voice commands, and the prompts" grep -q 'readonly property var headings: \["presence", "agents", "voice", "prompts"\]' "$AIPAGE"
check "a prompt is copied as an argument, never through a shell" grep -q 'execDetached(\["wl-copy", "--", modelData.text\])' "$AIPAGE"
# Pages were told apart by where they stood in the row; a tab put between two others
# would have shown every later page under the wrong name.
check "pages are shown by name, not by position" lacks -E 'visible: root\.current === [0-9]' "$PAGES/Dashboard.qml"
check "the large voice is only animated while it is looked at" grep -q 'running: page.active && page.heading === "presence"' "$AIPAGE"

# --- the network, the second heading of the infrastructure tab
# NetworkManager and the routing table are stubs: a laptop on Wi-Fi at home with a cable
# in as well, and a VPN that takes a few networks and leaves the rest alone.
cat >"$stubs/nmcli" <<'STUB'
#!/usr/bin/env bash
case "$*" in
*"connection show --active"*)
  printf '%s\n' 'the-vpn:vpn:eth0' 'Wired:802-3-ethernet:eth0' 'home\:net:802-11-wireless:wlan0' 'tun0:tun:tun0' 'lo:loopback:lo' ;;
*"device show"*)
  printf '%s\n' 'GENERAL.DEVICE:wlan0' 'GENERAL.TYPE:wifi' 'GENERAL.CONNECTION:home\:net' 'IP4.ADDRESS[1]:192.0.2.48/24' 'IP4.GATEWAY:192.0.2.1' 'IP4.DNS[1]:192.0.2.1' '' \
    'GENERAL.DEVICE:eth0' 'GENERAL.TYPE:ethernet' 'GENERAL.CONNECTION:Wired' 'IP4.ADDRESS[1]:10.1.2.3/24' 'IP4.GATEWAY:10.1.2.254' 'IP4.DNS[1]:10.1.2.53' 'IP4.DOMAIN[1]:lan.example' '' \
    'GENERAL.DEVICE:tun0' 'GENERAL.TYPE:tun' 'GENERAL.CONNECTION:tun0' 'IP4.ADDRESS[1]:172.16.0.9/32' 'IP4.GATEWAY:' 'IP4.DNS[1]:172.16.0.1' 'IP4.DOMAIN[1]:corp.example' '' \
    'GENERAL.DEVICE:lo' 'GENERAL.TYPE:loopback' 'GENERAL.CONNECTION:lo' 'IP4.ADDRESS[1]:127.0.0.1/8' ;;
*"device wifi"*) printf '%s\n' 'no:other:40:2412 MHz' 'yes:home\:net:71:5180 MHz' ;;
*connectivity*) echo full ;;
esac
STUB
cat >"$stubs/ip" <<'STUB'
#!/usr/bin/env bash
echo '[{"dst":"default","gateway":"10.1.2.254","dev":"eth0","metric":100},{"dst":"default","gateway":"192.0.2.1","dev":"wlan0","metric":600},{"dst":"10.1.2.0/24","dev":"eth0"},{"dst":"198.51.100.7","gateway":"10.1.2.254","dev":"eth0","protocol":"static","metric":50},{"dst":"172.21.0.0/16","gateway":"172.16.0.1","dev":"tun0","metric":50},{"dst":"172.20.0.0/16","gateway":"172.16.0.1","dev":"tun0","metric":50},{"dst":"172.3.0.0/16","gateway":"172.16.0.1","dev":"tun0","metric":50}]'
STUB
printf '#!/usr/bin/env bash\necho "64 bytes from $5: icmp_seq=1 ttl=64 time=1.5 ms"\n' >"$stubs/ping"
chmod +x "$stubs/nmcli" "$stubs/ip" "$stubs/ping"
network() { DESKTOP_NETWORKS_CONF="$sandbox/networks.conf" run network --json; }
answer=$(network)
net() { jq -r "$1" <<<"$answer"; }
check "the link traffic leaves by is the one with the lowest metric" test "$(net '.links[0] | "\(.dev)|\(.primary)"')" = "eth0|true"
check "the other link is listed, and is not the way out" test "$(net '.links[1] | "\(.dev)|\(.primary)"')" = "wlan0|false"
check "a Wi-Fi name with a colon in it is read whole" test "$(net '.links[1].ssid')" = "home:net"
check "with its signal and band" test "$(net '.links[1] | "\(.signal)|\(.band)"')" = "71|5 GHz"
check "the router is the way out's, and how fast it answers" test "$(net '.router | "\(.address)|\(.ms)"')" = "10.1.2.254|1.5"
check "a VPN is called by its own name, not its device's" test "$(net '.vpn[0] | "\(.connection)|\(.dev)"')" = "the-vpn|tun0"
check "and says how many networks go through it" test "$(net '.vpn[0] | "\(.routes)|\(.all)"')" = "3|false"
check "the tunnel is not counted among the links" test "$(net '.links | length')" = 2
check "unnamed, the place is what NetworkManager calls it, and says so" test "$(net '.place | "\(.name)|\(.kind)"')" = "Wired|unknown"
check "the same is said in sentences" grep -q "VPN the-vpn is up: 3 networks go through it" <<<"$(net '.lines[]')"
printf '%s\n' '# mine' 'Office | work | domain=lan.example' 'Home | home | ssid=home:net' >"$sandbox/networks.conf"
answer=$(network)
check "a place is named by your own list" test "$(net '.place | "\(.name)|\(.kind)"')" = "Office|work"
check "and says what gave it away" test "$(net '.place.why')" = "domain lan.example"
# A box in the picture opens what lies behind it, and the VPN's is every network it takes.
check "every network behind the VPN is listed, not the first eight" test "$(net '.vpn[0].route_list | length')" -eq 3
check "  in address order, as a person reads them" test "$(net '[.vpn[0].route_list[].dst] | join(" ")')" = "172.3.0.0/16 172.20.0.0/16 172.21.0.0/16"
check "  with the gateway they share said once" test "$(net '.vpn[0].gateways | join(" ")')" = "172.16.0.1"
check "the route the VPN keeps to its own server is named" test "$(net '[.links[0].route_list[] | select(.vpn_server) | .dst] | join(" ")')" = "198.51.100.7"
check "the ways out are listed, the one taken first" test "$(net '[.defaults[].dev] | join(" ")')" = "eth0 wlan0"
check "each connection says all its addresses" test "$(net '.links[0].addresses | join(" ")')" = "10.1.2.3/24"
check "every box in the picture opens its details" test "$(grep -cE 'key: "(machine|router|internet|vpn)"' "$PAGES/InfraPage.qml")" -eq 5
check "  and a shell command opens them too, for voice" grep -q 'function networkDetails(key: string)' "$ROOT/shell/shell.qml"
check "the details are not shown while the screen is shared" grep -q 'model: page.details && !Sharing.active ? page.details.routes' "$PAGES/InfraPage.qml"
check "  which Hyprland says on its event socket" grep -q 'event.name === "screencast"' "$ROOT/shell/Commons/Sharing.qml"
check "  and the shell knows Sharing" grep -q '^singleton Sharing 1.0 Sharing.qml$' "$ROOT/shell/Commons/qmldir"
check "the network is not a tab of its own" lacks -x network <<<"$(run tabs)"
check "no address is looked up outside" lacks -E 'https?://' "$ROOT/bin/desktop-dash-network"
check "the packets only travel while the page is looked at" grep -q 'visible: stretch.carries && page.active && page.heading === "network"' "$PAGES/InfraPage.qml"
check "the network is only asked while infrastructure is on show" grep -q 'running: root.lookedAt && root.shown && root.key === "infra"' "$PAGES/Dashboard.qml"

# --- the agents, a heading of the AI tab
# Its numbers are other commands' answers put together, so those are the stubs: two
# sessions, one of them waiting, and two agents with thirty days of tokens between them.
printf '%s\n' '#!/usr/bin/env bash' 'echo '"'"'{"sessions":[{"agent":"claude","project":"repo","state":"waiting","for":"2m","target":"s:1.1","socket":"/tmp/s"},{"agent":"claude","project":"other","state":"ready","for":"1h"}]}'"'" >"$stubs/desktop-agent-sessions"
printf '%s\n' '#!/usr/bin/env bash' 'echo '"'"'{"text":"5","tooltip":"2 claude, 3 codex"}'"'" >"$stubs/desktop-status-agents"
printf '%s\n' '#!/usr/bin/env bash' 'echo '"'"'{"tasks":[{"repo":"repo","name":"fix","ahead":2,"dirty":1,"state":"","target":"s:2.1"}]}'"'" >"$stubs/desktop-worktree"
printf '%s\n' '#!/usr/bin/env bash' 'echo '"'"'{"plan":"pro","limits":[{"name":"Weekly","percent":40,"resets":"Fri"}]}'"'" >"$stubs/desktop-status-claude"
cat >"$stubs/desktop-agent-tokens" <<'STUB'
#!/usr/bin/env python3
import json
def day(n, burned, read=0, answers=0):
    return {"date": f"2026-09-{n:02d}", "input": burned, "cache_write": 0, "cache_read": read, "output": 0, "burned": burned, "answers": answers}
claude = [day(n, 0) for n in range(1, 17)] + [day(n, 100) for n in range(17, 24)] + [day(n, 200, read=600, answers=10) for n in range(24, 31)]
idle = [day(n, 0) for n in range(1, 31)]
hours = [0] * 24
hours[9] = 200
print(json.dumps({"days": [d["date"] for d in claude], "window_hours": 5, "agents": [
    {"id": "claude", "name": "Claude Code", "present": True, "days": claude, "today": claude[-1], "window": {"burned": 150}, "hours": hours},
    {"id": "codex", "name": "Codex", "present": True, "days": idle, "today": idle[-1], "window": {"burned": 0}, "hours": [0] * 24}]}))
STUB
chmod +x "$stubs"/desktop-agent-sessions "$stubs"/desktop-status-agents "$stubs"/desktop-worktree "$stubs"/desktop-status-claude "$stubs"/desktop-agent-tokens
answer=$(PATH="$stubs:$PATH" python3 "$ROOT/bin/desktop-dash-agents")
ag() { jq -r "$1" <<<"$answer"; }
check "every agent running is counted, the ones that report no state too" test "$(ag '.running')" = 5
check "a session in no state it knows is open, not lost" test "$(ag '.states | "\(.waiting)|\(.open)|\(.working)"')" = "1|1|0"
check "a session keeps what is needed to go to it" test "$(ag '.sessions[0] | "\(.project)|\(.target)|\(.socket)"')" = "repo|s:1.1|/tmp/s"
check "the tasks and Claude's limits come along" test "$(ag '"\(.tasks[0].name)|\(.plan)|\(.limits[0].percent)"')" = "fix|pro|40"
check "this week is the last seven days" test "$(ag '.agents[0].week')" = 1400
check "set against the seven before them" test "$(ag '.agents[0] | "\(.before)|\(.change)"')" = "700|100"
check "the average is over days in use, not over the calendar" test "$(ag '.agents[0] | "\(.active_days)|\(.average)"')" = "14|150"
check "how much was read from the cache is a share of everything read" test "$(ag '.agents[0].cached')" = 67
check "tokens an answer, over the week" test "$(ag '.agents[0].per_answer')" = 20
check "the busiest hour of today" test "$(ag '.agents[0].busiest_hour')" = 9
check "an agent with nothing in thirty days says so, and divides by nothing" test "$(ag '.agents[1] | "\(.present)|\(.average)|\(.change)|\(.best)"')" = "false|0|0|null"
check "the month is every agent's, a day to a bar" test "$(ag '"\(.days | length)|\(.month)"')" = "30|2100"
check "a month of bars is dated under its Mondays only" test "$(ag '[.days[] | select(.label != "")] | map(.label) | join(",")')" = "7 Sep,14 Sep,21 Sep,28 Sep"
printf '#!/usr/bin/env bash\nexit 1\n' >"$stubs/desktop-agent-tokens"
answer=$(PATH="$stubs:$PATH" python3 "$ROOT/bin/desktop-dash-agents")
check "a command that fails leaves its part empty and the rest an answer" test "$(ag '"\(.agents | length)|\(.sessions | length)"')" = "0|2"
check "the agents are not a tab of their own" lacks -x agents <<<"$(run tabs)"
check "the agents' cards have left the start page" lacks -E 'title: "(Agents|Tasks|Claude)"' "$PAGES/StartPage.qml"
check "the agents are only asked while the AI tab is on show" grep -q 'running: root.lookedAt && root.shown && root.key === "ai"' "$PAGES/Dashboard.qml"

finish
