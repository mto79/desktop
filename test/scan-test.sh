#!/usr/bin/env bash
# The network and Bluetooth scanners. What is checked first is what they must not do: ping
# a network that is not yours unless asked, sweep more than a /24, turn Bluetooth on, or
# leave what they found readable by others. Then that what they say is right: makers,
# names, private addresses, this machine counted once, a distance from a signal.
#
# Every tool is a stub writing down how it was called. Nothing here sends a packet or
# switches on a radio.
source "$(dirname "$0")/lib.sh"

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
stubs="$sandbox/bin"
mkdir -p "$stubs"
calls="$sandbox/calls"

stub() { # name, then the body
  printf '#!/usr/bin/env bash\necho "%s $*" >>"%s"\n%s\n' "$1" "$calls" "$2" >"$stubs/$1"
  chmod +x "$stubs/$1"
}

# Where we are: kind and prefix are what the tests change.
place() {
  cat >"$sandbox/where.json" <<EOF
{"place": {"name": "Somewhere", "kind": "$1"},
 "links": [{"dev": "eth0", "kind": "ethernet", "primary": true, "address": "192.0.2.10/$2", "gateway": "192.0.2.1", "connection": "Wired"}]}
EOF
}
stub desktop-dash-network "cat '$sandbox/where.json'"
# 192.0.2.1 (router) and .20 answer; nobody else does.
stub ping 'case "$*" in *192.0.2.1|*192.0.2.20) echo "64 bytes from x: icmp_seq=1 ttl=64 time=0.84 ms" ;; esac'
stub ip 'case "$*" in
*neigh*) echo "[{\"dst\":\"192.0.2.1\",\"lladdr\":\"00:00:5e:00:53:01\",\"state\":[\"REACHABLE\"]},{\"dst\":\"192.0.2.30\",\"lladdr\":\"aa:bb:cc:dd:ee:ff\",\"state\":[\"STALE\"]},{\"dst\":\"192.0.2.99\",\"state\":[\"FAILED\"]}]" ;;
*addr*) echo "[{\"address\":\"00:00:5e:00:53:10\",\"addr_info\":[{\"local\":\"192.0.2.10\"}]},{\"address\":\"00:00:5e:00:53:11\",\"addr_info\":[{\"local\":\"192.0.2.11\"}]}]" ;;
esac'
stub avahi-browse 'echo "=;eth0;IPv4;Living\\032room\\032speaker;_googlecast._tcp;local;speaker.local;192.0.2.20;8009;"
echo "=;eth0;IPv4;Living\\032room\\032speaker;_spotify-connect._tcp;local;speaker.local;192.0.2.20;443;"
echo "=;tun0;IPv4;Elsewhere;_http._tcp;local;far.local;198.51.100.5;80;"'
stub getent 'case "$*" in *192.0.2.1) echo "192.0.2.1 _gateway" ;; *192.0.2.20) echo "192.0.2.20 speaker.example" ;; esac'
stub nmcli 'echo "*:00\:00\:5E\:00\:53\:AA:Home\:net:44:5220 MHz:73:WPA2"; echo " :00\:00\:5E\:00\:53\:BB::1:2412 MHz:40:WPA2"'
printf '00-00-5E   (hex)\t\tICANN, IANA Department\n' >"$sandbox/oui.txt"

netscan() {
  : >"$calls"
  PATH="$stubs:$PATH" XDG_STATE_HOME="$sandbox/state" DESKTOP_OUI="$sandbox/oui.txt" "$ROOT/bin/desktop-netscan" scan "$@"
}
pings() { grep -c '^ping ' "$calls"; }

# --- the network
place unknown 24
answer=$(netscan)
check "off a network of yours a scan sends nothing" test "$(pings)" -eq 0
check "  and says so" test "$(jq -r .swept <<<"$answer")" = false
check "  but still says what is already known" test "$(jq '.devices | length' <<<"$answer")" -ge 3
check "  and the Wi-Fi around" test "$(jq '.wifi | length' <<<"$answer")" -eq 2
answer=$(netscan --sweep)
check "--sweep pings every address there" test "$(pings)" -eq 253

place home 24
answer=$(netscan)
check "on a network marked home a scan sweeps by itself" test "$(jq -r .swept <<<"$answer")" = true
place home 16
answer=$(netscan)
check "a /16 is swept for this machine's /24 only, not 65000 addresses" test "$(pings)" -eq 253
check "  and says so" test "$(jq -r .mode <<<"$answer")" = "own /24 of a wider subnet"

place home 24
answer=$(netscan)
dev() { jq -r ".devices[] | select(.ip == \"$1\") | $2" <<<"$answer"; }
check "the router is found, with its latency" test "$(dev 192.0.2.1 '"\(.gateway)|\(.ms)"')" = "true|0.8"
check "  and _gateway, resolved's placeholder, is not taken for its name" test "$(dev 192.0.2.1 .rdns)" = ""
check "a maker is looked up by the MAC's first half" test "$(dev 192.0.2.1 .vendor)" = "ICANN, IANA Department"
check "a private MAC is said to be one, not given a maker" test "$(dev 192.0.2.30 '"\(.private)|\(.vendor)"')" = "true|private address"
check "a device's own name over mDNS is read, spaces and all" test "$(dev 192.0.2.20 .name)" = "Living room speaker"
check "  with what it offers" test "$(dev 192.0.2.20 '.services | join(",")')" = "googlecast,spotify-connect"
check "  and an announcement from another link is not taken for this one" test -z "$(dev 198.51.100.5 .ip)"
check "a neighbour that failed is not a device" test -z "$(dev 192.0.2.99 .ip)"
check "this machine's other address is this machine too, not a stranger" test "$(dev 192.0.2.11 .me)" = true
check "  and this machine is not pinged" lacks -q 'ping .*192.0.2.10$' "$calls"
check "the answer is kept for you alone" test "$(stat -c %a "$sandbox/state/desktop/netscan/last.json")" = 600
check "  and read back without scanning" test "$(PATH="$stubs:$PATH" XDG_STATE_HOME="$sandbox/state" "$ROOT/bin/desktop-netscan" last | jq -r .swept)" = true
check "no port is ever knocked on" lacks -qE 'run\("(nmap|nc|ncat|arp-scan)"' "$ROOT/bin/desktop-netscan"

# --- Bluetooth
: >"$calls"
stub bluetoothctl 'case "$*" in
show) cat "'"$sandbox"'/powered" ;;
"devices") echo "Device 00:00:5E:00:53:A1 Headphones"; echo "Device 00:00:5E:00:53:A2 00-00-5E-00-53-A2" ;;
"info 00:00:5E:00:53:A1") printf "Device 00:00:5E:00:53:A1 (public)\n\tName: Headphones\n\tAlias: Headphones\n\tIcon: audio-headset\n\tPaired: yes\n\tConnected: no\n\tUUID: Audio Sink (0000110b-0000-1000-8000-00805f9b34fb)\n\tUUID: Unknown (00000000-0000-1000-8000-00805f9b34fb)\n\tBattery Percentage: 0x50 (80)\n" ;;
"info 00:00:5E:00:53:A2") printf "Device 00:00:5E:00:53:A2 (random)\n\tAlias: 00-00-5E-00-53-A2\n\tPaired: no\n\tManufacturerData.Key: 0x004c (76)\n\tManufacturerData.Value:\n  10 05 01 00 00 00 00 00                          ........\n" ;;
*scan*) echo "[CHG] Device 00:00:5E:00:53:A2 RSSI: 0xffffffc1 (-63)"; echo "[CHG] Device 00:00:5E:00:53:A2 RSSI: 0xffffffb0 (-80)" ;;
esac'
btscan() {
  : >"$calls"
  PATH="$stubs:$PATH" XDG_STATE_HOME="$sandbox/state" "$ROOT/bin/desktop-btscan" scan 3
}
echo "Powered: no" >"$sandbox/powered"
answer=$(btscan)
check "Bluetooth that is off is left off" lacks -qE 'power on|scan on' "$calls"
check "  and the answer says it is off" test "$(jq -r .why <<<"$answer")" = "Bluetooth is off"

echo "Powered: yes" >"$sandbox/powered"
answer=$(btscan)
bt() { jq -r ".devices[] | select(.address == \"$1\") | $2" <<<"$answer"; }
check "a device heard is near, by its strongest signal" test "$(bt 00:00:5E:00:53:A2 '"\(.near)|\(.rssi)"')" = "true|-63"
check "  with a distance worked out from it" test "$(bt 00:00:5E:00:53:A2 .metres)" = "1.4"
check "  its random address said to be one" test "$(bt 00:00:5E:00:53:A2 .random)" = true
check "  and an address for a name is no name" test "$(bt 00:00:5E:00:53:A2 .name)" = ""
check "Apple's data says what the device is doing" test "$(bt 00:00:5E:00:53:A2 '"\(.maker)|\(.doing)|\(.kind)"')" = "Apple|iPhone, iPad or Mac nearby|phone"
check "a paired device not heard is listed, as not near" test "$(bt 00:00:5E:00:53:A1 '"\(.near)|\(.paired)|\(.kind)|\(.battery)"')" = "false|true|headphones|80"
check "  with what it does, and no Unknown among it" test "$(bt 00:00:5E:00:53:A1 '.services | join(",")')" = "Audio Sink"
check "the near come first" test "$(jq -r '.devices[0].address' <<<"$answer")" = "00:00:5E:00:53:A2"
check "the answer is kept for you alone" test "$(stat -c %a "$sandbox/state/desktop/btscan/last.json")" = 600
check "nothing is paired, trusted or connected by a scan" lacks -qE 'bluetoothctl (pair|trust|connect)' "$calls"

# --- the shell
PAGE="$ROOT/shell/Dashboard/InfraPage.qml"
check "Bluetooth is a heading of the infrastructure tab" grep -q '"clusters", "network", "bluetooth"' "$PAGE"
check "the panel and the dashboard share one scan" grep -q 'Scans.scanNetwork' "$ROOT/shell/Bar/panels/NetworkPanel.qml"
check "  which never starts by itself" lacks -q 'Timer' "$ROOT/shell/Commons/Scans.qml"
check "the devices are hidden while the screen is shared, in the panel too" grep -q '!Sharing.active ? Scans.network.devices' "$ROOT/shell/Bar/panels/NetworkPanel.qml"
check "  and so are the Wi-Fi networks around" grep -q 'page.scan.wifi && !Sharing.active' "$PAGE"
check "names from the network are never rendered as HTML" grep -q 'textFormat: Text.PlainText' "$ROOT/shell/Dashboard/Quiet.qml"
check "  nor a Wi-Fi network's name under its bar" grep -q 'textFormat: Text.PlainText' "$ROOT/shell/Dashboard/Bars.qml"
check "the shell knows Scans" grep -q '^singleton Scans 1.0 Scans.qml$' "$ROOT/shell/Commons/qmldir"

finish
