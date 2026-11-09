#!/usr/bin/env bash
# The feeds behind the globe, read from fixtures. What matters: a feed that is down keeps
# its last copy and says so, what has no key says how to get one rather than looking broken,
# and a coordinate lands where the texture has that place.
source "$(dirname "$0")/lib.sh"

require python3 || finish
require jq || finish

SCANNER="$ROOT/bin/desktop-scanner"
GLOBE="$ROOT/shell/Dashboard/Globe.qml"
sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
export HOME="$sandbox" XDG_CACHE_HOME="$sandbox/cache" XDG_CONFIG_HOME="$sandbox/config"
export DESKTOP_SCANNER_FIXTURES="$sandbox/feeds"
mkdir -p "$sandbox/feeds" "$sandbox/bin"
# The secret store is this machine's own, keys and all: the test must not ask it.
printf '#!/usr/bin/env bash\nexit 1\n' >"$sandbox/bin/secret-tool"
chmod +x "$sandbox/bin/secret-tool"
export PATH="$sandbox/bin:$PATH"

cat >"$sandbox/feeds/planes.txt" <<'JSON'
{"time": 1, "states": [
 ["abc123", "KLM1234 ", "Netherlands", 0, 0, 4.9, 52.3, 11000, false, 230.0, 90, 0, null, null, null, false, 0],
 ["def456", "ONGROUND", "Netherlands", 0, 0, 4.7, 52.3, 0, true, 0, 0, 0, null, null, null, false, 0],
 ["fed789", null, "Spain", 0, 0, null, null, null, false, null, null, 0, null, null, null, false, 0]]}
JSON
cat >"$sandbox/feeds/ships.txt" <<'JSON'
{"features": [{"mmsi": 230000001, "geometry": {"coordinates": [24.9, 60.1]}, "properties": {"sog": 12.5}}]}
JSON
cat >"$sandbox/feeds/quakes.txt" <<'JSON'
{"features": [{"geometry": {"coordinates": [140.0, 36.0, 10]}, "properties": {"mag": 5.5, "place": "Honshu"}}]}
JSON
cat >"$sandbox/feeds/feodo.txt" <<'JSON'
[{"ip_address": "192.0.2.1", "malware": "QakBot", "country": "US"}]
JSON
printf '#ip,ioc\n192.0.2.2,Possible Cobaltstrike C2 IP\n192.0.2.3,Possible Sliver C2 IP\n' >"$sandbox/feeds/c2intel.txt"
cat >"$sandbox/feeds/geo.txt" <<'JSON'
[{"status": "success", "query": "192.0.2.1", "lat": 40.0, "lon": -74.0, "country": "United States"},
 {"status": "success", "query": "192.0.2.2", "lat": 52.0, "lon": 5.0, "country": "Netherlands"},
 {"status": "fail", "query": "192.0.2.3"}]
JSON

answer=$("$SCANNER" --json)
layer() { jq -r ".layers[] | select(.key == \"$1\") | $2" <<<"$answer"; }

check "an aircraft on the ground or without a position is left out" test "$(layer planes .count)" = 1
check "a callsign loses its padding" test "$(layer planes '.rows[0][2]')" = KLM1234
check "with its height and speed" grep -q '11,000 m · 828 km/h' <<<"$(layer planes '.rows[0][3]')"
check "a ship is placed" test "$(layer ships '.rows[0][0]')" = 60.1
check "and says it only covers the Baltic" grep -q Baltic <<<"$(layer ships .note)"
check "a quake is placed with its magnitude" test "$(layer quakes '.rows[0][2]')" = M5.5
check "a server is named for what it runs" grep -q 'QakBot C2 · United States' <<<"$(layer malware '[.rows[][3]] | join(";")')"
check "and the 'possible' and the 'IP' are dropped" grep -q '^Cobaltstrike C2 · ' <<<"$(layer malware '.rows[1][3]')"
check "a server ip-api cannot place is left off the map" test "$(layer malware .count)" = 2
check "what was placed is remembered" grep -q 192.0.2.2 "$sandbox/cache/desktop/scanner/geo.json"

check "no key is not a failure: it says how" grep -q 'secret-tool store' <<<"$(layer wifi '.how[0]')"
check "and has nothing to draw" test -z "$(layer wifi .file)"

file=$(layer planes .file)
check "a layer is a table the GPU can draw" grep -q '<Instance position=' "$file"
check "with one row per dot" test "$(grep -c '<Instance ' "$file")" = 1

# A feed that goes away keeps what it last said, and says it is old. Aged by hand, or the
# copy is still young enough not to ask at all.
python3 - "$sandbox/cache/desktop/scanner/ships.json" <<'PY'
import json, sys
copy = json.load(open(sys.argv[1]))
copy["at"] -= 3600
json.dump(copy, open(sys.argv[1], "w"))
PY
rm "$sandbox/feeds/ships.txt"
answer=$("$SCANNER" --json)
check "a feed that is down keeps its last copy" test "$(layer ships .count)" = 1
check "and says so" grep -q 'showing the last copy' <<<"$(layer ships .note)"
check "and is marked" test "$(layer ships .ok)" = false

check "--cached does not touch the network" test "$("$SCANNER" --json --cached | jq '.layers | length')" = 6
check "one bad feed leaves the others" test "$(layer planes .ok)" = true

# The script places the dots and the page places the marks, so both must do the same sum:
# longitude 0 at +z, east at +x, north at +y. Calibrated by eye against the Black Marble.
where() {
  python3 - "$1" "$2" "$SCANNER" <<'PY'
import importlib.machinery, importlib.util, sys
loader = importlib.machinery.SourceFileLoader("scanner", sys.argv[3])
spec = importlib.util.spec_from_loader("scanner", loader)
module = importlib.util.module_from_spec(spec)
loader.exec_module(module)
print(" ".join(f"{v:.0f}" for v in module.position(float(sys.argv[1]), float(sys.argv[2]))))
PY
}
check "longitude 0 faces +z" test "$(where 0 0)" = "0 0 100"
check "east is +x" test "$(where 0 90)" = "100 0 0"
check "north is +y" test "$(where 90 0)" = "0 100 0"
check "the page does the same sum" grep -q 'r \* Math.cos(a) \* Math.sin(b), r \* Math.sin(a), r \* Math.cos(a) \* Math.cos(b)' "$GLOBE"

# --- the page
PAGE="$ROOT/shell/Dashboard/SecurityPage.qml"
check "the globe is loaded apart, so a missing QtQuick3D cannot take the shell with it" \
  grep -q 'source: "Globe.qml"' "$PAGE"
check "and only the globe imports it" test "$(grep -l 'import QtQuick3D' "$ROOT"/shell/*/*.qml "$ROOT"/shell/*.qml | wc -l)" = 1
check "it stops turning off screen" grep -q 'running: globe.running && !drag.pressed' "$GLOBE"
# One animation that never ends redraws the planet at the refresh rate for as long as the
# page is open, which is what the malware layer's pulse used to do. Nothing may.
check "nothing in the scene animates forever" lacks 'Animation.Infinite' "$GLOBE"
check "it settles after a while, and then draws nothing" grep -q '!globe.settled' "$GLOBE"
check "the dots are only handed over when a feed changed" grep -q 'stamp !== page.drawnStamp' "$PAGE"
check "the dot under the pointer is found through a grid, not a walk over all of them" grep -q 'grid\[(homeLat + y)' "$GLOBE"

# --- one aircraft, clicked
cat >"$sandbox/feeds/hexdb-aircraft.txt" <<'JSON'
{"ModeS": "484506", "Registration": "PH-TST", "Manufacturer": "Boeing", "Type": "737NG", "RegisteredOwners": "Example Air"}
JSON
printf '{"flight": "KLM1234", "route": "ESGG-EHAM"}\n' >"$sandbox/feeds/hexdb-route.txt"
printf '{"icao": "EHAM", "airport": "Example Airport"}\n' >"$sandbox/feeds/hexdb-airport.txt"
plane=$("$SCANNER" --aircraft 484506 'KLM1234')
check "a clicked aircraft gets its type" test "$(jq -r .type <<<"$plane")" = 737NG
check "and its owner" test "$(jq -r .owner <<<"$plane")" = "Example Air"
check "and the route, by airport name" grep -q 'Example Airport  →  Example Airport' <<<"$(jq -r .route <<<"$plane")"
check "and somewhere to follow it" test "$(jq -r .track <<<"$plane")" = "https://globe.adsbexchange.com/?icao=484506"
rm "$sandbox"/feeds/hexdb-*
check "and is remembered" test "$("$SCANNER" --aircraft 484506 'KLM1234' | jq -r .type)" = 737NG
weird=$("$SCANNER" --aircraft '../../x;rm' '$(id)')
check "an address from a feed cannot name a path" test "$(jq -r .hex <<<"$weird")" = "" -o -z "$(find "$sandbox/cache" -name '*rm*')"
check "a plane no one knows still has what the feed said" test "$("$SCANNER" --aircraft abcdef XX | jq -r .hex)" = abcdef

# --- webcams
cams=$("$SCANNER" --webcams 52.37 4.90 40)
check "webcams without a key say how to get one" grep -q 'api.windy.com/keys' <<<"$(jq -r '.how[0]' <<<"$cams")"
check "and ask nothing" test "$(jq '.cams | length' <<<"$cams")" = 0
cat >"$sandbox/feeds/webcams.txt" <<'JSON'
{"total": 3, "webcams": [
 {"webcamId": 1, "status": "active", "title": "Dam Square", "location": {"city": "Amsterdam", "country": "Netherlands", "latitude": 52.373, "longitude": 4.893},
  "images": {"current": {"icon": "https://imgproxy.windy.com/i.jpg", "thumbnail": "https://imgproxy.windy.com/t.jpg", "preview": "https://imgproxy.windy.com/p.jpg"}},
  "urls": {"detail": "https://www.windy.com/webcams/1"}, "player": {"day": "https://webcams.windy.com/webcams/public/embed/player/1/day"}},
 {"webcamId": 2, "status": "active", "title": "Elsewhere", "location": {"city": "X", "country": "Y", "latitude": 52.1, "longitude": 4.5},
  "images": {"current": {"preview": "http://example.org/plain.jpg"}}, "urls": {"detail": "https://evil.example/1"}},
 {"webcamId": 3, "status": "inactive", "title": "Broken", "location": {"latitude": 52.2, "longitude": 4.6}}]}
JSON
cams=$(DESKTOP_SCANNER_WINDY_KEY=k "$SCANNER" --webcams 52.37 4.90 400)
check "an inactive webcam is left out" test "$(jq '.cams | length' <<<"$cams")" = 2
check "the radius is held to Windy's 250 km" test "$(jq .km <<<"$cams")" = 250
check "a webcam has its picture, the largest Windy names" test "$(jq -r '.cams[0].image' <<<"$cams")" = https://imgproxy.windy.com/p.jpg
check "and its place" test "$(jq -r '.cams[0].place' <<<"$cams")" = "Amsterdam, Netherlands"
check "a picture not from Windy over https is not shown" test -z "$(jq -r '.cams[1].image' <<<"$cams")"
check "nor a link anywhere but Windy" test -z "$(jq -r '.cams[1].link' <<<"$cams")"
check "a webcam has its timelapse" test "$(jq -r '.cams[0].player' <<<"$cams")" = https://webcams.windy.com/webcams/public/embed/player/1/day
check "they are a layer on the globe" grep -q '<Instance position=' "$(jq -r .layer.file <<<"$cams")"
check "copied for less than Windy's links last" grep -q '^CAMS_EVERY = 480$' "$SCANNER"
check "the credit Windy asks for is shown" test "$(grep -c 'Webcams provided by <a href' "$PAGE")" -ge 2
check "a picture opens in a pop-up, not the browser" grep -q 'onClicked: page.camOpen = parent.cam' "$PAGE"
check "whose picture plays Windy's timelapse, as their terms ask of a picture" grep -q 'onClicked: page.playTimelapse(camColumn.cam)' "$PAGE"
check "which floats over the dashboard" grep -q 'match:class brave-webcams' "$ROOT/default/hypr/apps/webcams.conf"
check "and the Lua twin says the same" grep -q 'class = "brave-webcams' "$ROOT/default/hypr/apps/webcams.lua"
check "webcams are asked for on the way in, before they are shown" grep -q 'view.altitude <= preloadFrom' "$PAGE"
check "and not again for a view that moved a little" grep -q 'stillCovered(camAsked' "$PAGE"
check "webcams are asked for only zoomed in" grep -q 'view.altitude <= camsFrom' "$PAGE"
check "and only once the view is still" grep -q 'signal looked(' "$GLOBE"

# --- natural events
cat >"$sandbox/feeds/events.txt" <<'JSON'
{"events": [
 {"title": "Tropical Cyclone Test", "categories": [{"title": "Severe Storms"}], "sources": [{"url": "https://example.org/storm"}],
  "geometry": [{"type": "Point", "date": "2026-11-01T00:00:00Z", "coordinates": [70.0, 10.0]},
               {"type": "Point", "date": "2026-11-03T06:00:00Z", "coordinates": [80.2, 15.8], "magnitudeValue": 65.0, "magnitudeUnit": "kts"}]},
 {"title": "Fire", "categories": [{"title": "Wildfires"}], "sources": [{"url": "http://example.org/plain"}],
  "geometry": [{"type": "Polygon", "date": "2026-11-02", "coordinates": [[[0, 0], [2, 0], [2, 2], [0, 2]]]}]},
 {"title": "Nowhere", "categories": [], "geometry": []}]}
JSON
rm -f "$sandbox/cache/desktop/scanner/events.json"
answer=$("$SCANNER" --json)
check "an event with nowhere to be is left out" test "$(layer events .count)" = 2
check "a storm is where it was last reported" test "$(layer events '.rows[0][0:2] | join(",")')" = "15.8,80.2"
check "with what it is, when and how strong" test "$(layer events '.rows[0][3]')" = "Severe Storms · 2026-11-03 · 65 kts"
check "a fire's outline is its middle" test "$(layer events '.rows[1][0] == 1 and .rows[1][1] == 1')" = true
check "a link is kept only if it is https" test -z "$(layer events '.rows[1][4]')"

# --- aircraft, live
cat >"$sandbox/feeds/live.txt" <<'JSON'
{"ac": [{"hex": "400981", "flight": "BAW965  ", "t": "A320", "r": "G-TEST", "lat": 52.0, "lon": 3.5, "alt_baro": 34000, "gs": 492.3, "track": 246.6},
        {"hex": "abc123", "flight": "TAXI1", "lat": 52.3, "lon": 4.7, "alt_baro": "ground"},
        {"hex": "def456", "flight": "NOPOS"}]}
JSON
flying=$("$SCANNER" --live 52.3 4.8 900)
check "live aircraft on the ground or without a position are left out" test "$(jq .layer.count <<<"$flying")" = 1
check "with type, registration, height and speed" test "$(jq -r '.layer.rows[0][3]' <<<"$flying")" = "A320 · G-TEST · 10,400 m · 912 km/h"
check "and the address that a click asks about" test "$(jq -r '.layer.rows[0][4]' <<<"$flying")" = 400981
check "the radius is held to adsb.lol's 250 nautical miles" test "$(jq .km <<<"$flying")" = 463
check "OpenSky's older aircraft are not drawn beside the live ones" grep -q 'out\["planes"\] = true' "$PAGE"
check "live aircraft are asked for every ten seconds, zoomed in only" grep -q 'running: page.scanning && page.liveWanted' "$PAGE"

# --- the zoom
check "a click's latitude comes from the direction, not the coarse sphere's radius" grep -q 'Math.atan2(p.y, Math.sqrt' "$GLOBE"
check "it zooms to a couple of hundred kilometres up" grep -q 'Math.max(2.5, Math.min(320' "$GLOBE"
check "and the dots keep their size on screen" grep -q 'scale: Qt.vector3d(globe.dotScale' "$GLOBE"
check "the scanner asks only while it is on show" grep -q 'running: page.scanning' "$PAGE"
check "the events are not drawn on a shared screen" grep -q 'page.heading === "events" && !Sharing.active' "$PAGE"
check "nor is home" grep -q 'page.scan && !Sharing.active ? page.scan.home : null' "$PAGE"
check "the packages it needs are installed" \
  test "$(grep -cxE 'qt6-qtquick3d|qt6-qtshadertools' "$ROOT/install/desktop-base.packages")" = 2

finish
