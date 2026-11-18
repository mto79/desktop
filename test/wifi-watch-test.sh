#!/usr/bin/env bash

# desktop-wifi-watch: the message wifi.conf names for the network connected to, once per
# connection, and nothing for a network it does not name.

source "$(dirname "$0")/lib.sh"

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
mkdir -p "$sandbox/stubs"
cat >"$sandbox/stubs/nmcli" <<STUB
#!/usr/bin/env bash
[[ -s "$sandbox/ssid" ]] && echo "yes:\$(cat "$sandbox/ssid")"
echo "no:somebody-else"
STUB
chmod +x "$sandbox/stubs/nmcli"
printf '# a comment\nmy home = Welcome home\nwork-guest = Visitors network: turn on the VPN\n' >"$sandbox/wifi.conf"

once() {
  env -i PATH="$sandbox/stubs:/usr/bin:/bin" DESKTOP_WIFI_CONF="$sandbox/wifi.conf" \
    DESKTOP_WIFI_SEND="$sandbox/sent" bash "$ROOT/bin/desktop-wifi-watch" --once
}
: >"$sandbox/sent"

echo "my home" >"$sandbox/ssid"
once
check "a network named in wifi.conf, spaces and all, gets its message" \
  grep -qx $'my home\tWelcome home' "$sandbox/sent"
: >"$sandbox/sent"
echo "coffee-shop" >"$sandbox/ssid"
once
check "a network it does not name says nothing" test ! -s "$sandbox/sent"
echo "work-guest" >"$sandbox/ssid"
once
check "  and the message is the whole rest of the line" \
  grep -qx $'work-guest\tVisitors network: turn on the VPN' "$sandbox/sent"
check "it starts with the session" grep -q 'desktop-wifi-watch' "$ROOT/default/hypr/autostart.lua"
check "and no network of anybody's is in the repository's wifi.conf" \
  test -z "$(grep -vE '^[[:space:]]*(#|$)' "$ROOT/config/desktop/wifi.conf")"

finish
