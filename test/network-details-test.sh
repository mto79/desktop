#!/usr/bin/env bash
# desktop-network-details, with ip, nmcli and iw faked as a docked laptop: wired and
# Wi-Fi both up, the wired link with the lower metric.
#
# The one mistake worth guarding is naming the wrong link: NetworkManager calls both
# "connected", and the panel has to describe the one traffic leaves by.
source "$(dirname "$0")/lib.sh"

require jq || finish

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
mkdir -p "$sandbox/path"
for tool in bash env jq awk sed cat find; do ln -s "$(command -v "$tool")" "$sandbox/path/$tool"; done
stub() { cat >"$sandbox/path/$1"; chmod +x "$sandbox/path/$1"; }

stub ip <<'STUB'
#!/usr/bin/env bash
echo "[{\"dev\":\"wlan9\",\"metric\":600},{\"dev\":\"$WIRED\",\"metric\":100}]"
STUB
stub nmcli <<'STUB'
#!/usr/bin/env bash
case "$*" in
"-t -f DEVICE,STATE device") printf 'eth9:connected\nwlan9:connected\nlo:connected (externally)\ntun0:connected (externally)\n' ;;
"-t device show eth9") printf 'GENERAL.TYPE:ethernet\nGENERAL.HWADDR:28:00:AF:C5:28:CD\nGENERAL.MTU:1500\nGENERAL.CONNECTION:dock\nIP4.ADDRESS[1]:192.168.2.7/24\nIP4.GATEWAY:192.168.2.1\nIP4.DNS[1]:192.168.2.1\nIP4.DNS[2]:9.9.9.9\nIP6.ADDRESS[1]:fe80::1/64\nIP6.ADDRESS[2]:2001:db8::7/64\nIP6.GATEWAY:\n' ;;
"-t device show wlan9") printf 'GENERAL.TYPE:wifi\nGENERAL.CONNECTION:home\nIP4.ADDRESS[1]:192.168.2.48/24\nIP4.GATEWAY:192.168.2.1\n' ;;
"-t device show tun0") printf 'GENERAL.TYPE:tun\nGENERAL.CONNECTION:tun0\nIP4.ADDRESS[1]:10.8.32.94/32\n' ;;
esac
STUB
stub iw <<'STUB'
#!/usr/bin/env bash
printf 'Connected to 60:22:32:ac:9a:2f (on wlan9)\n\tSSID: home "5G"\n\tfreq: 5220.0\n\tsignal: -44 dBm\n\ttx bitrate: 1200.9 MBit/s 80MHz HE-MCS 11 HE-NSS 2\n'
STUB

details() { env -i PATH="$sandbox/path" WIRED="${1:-eth9}" bash "$ROOT/bin/desktop-network-details"; }
out=$(details)

check "the link with the lowest metric is the one described" test "$(jq -r .primary.iface <<<"$out")" = eth9
check "with its address, gateway and every DNS server" \
  test "$(jq -c '.primary | [.ipv4, .gateway, .dns]' <<<"$out")" = '[["192.168.2.7/24"],"192.168.2.1",["192.168.2.1","9.9.9.9"]]'
check "IPv6 link-local addresses are left out" test "$(jq -c .primary.ipv6 <<<"$out")" = '["2001:db8::7/64"]'
check "an empty gateway is null, not an empty string" test "$(jq -c .primary.gateway6 <<<"$out")" = null
check "the spare links are listed, the loopback is not" test "$(jq -c '[.others[].iface]' <<<"$out")" = '["wlan9","tun0"]'

# Undocked: the wired link is gone, Wi-Fi carries the route.
out=$(details wlan9)
check "on Wi-Fi, the band and standard come from iw" \
  test "$(jq -c '.primary.wifi | [.band, .standard, .signal_dbm, .bitrate]' <<<"$out")" = '["5 GHz","Wi-Fi 6",-44,1200]'
check "and an SSID with quotes in it survives" test "$(jq -r .primary.wifi.ssid <<<"$out")" = 'home "5G"'

finish
