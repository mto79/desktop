#!/usr/bin/env bash
# desktop-vpn-details, with nmcli and ip faked as a split OpenVPN tunnel.
#
# vpn.data holds certificate paths and options along with the server, and only the
# server may come out of it. The rest are the facts the panel states: split or full,
# how many networks -- not counting the two host routes every tunnel adds for itself --
# and which device carries it.
source "$(dirname "$0")/lib.sh"

require jq || finish

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
mkdir -p "$sandbox/path"
for tool in bash env jq awk sed grep head cut paste; do ln -s "$(command -v "$tool")" "$sandbox/path/$tool"; done
stub() { cat >"$sandbox/path/$1"; chmod +x "$sandbox/path/$1"; }
stub nmcli <<'STUB'
#!/usr/bin/env bash
case "$*" in
"-t -f NAME,TYPE connection show --active") printf 'dock:802-3-ethernet\nwork:vpn\n' ;;
"-t connection show work")
  printf 'connection.timestamp:1789714745\nipv4.never-default:yes\n'
  printf 'vpn.data:auth = SHA256, ca = /home/u/.cert/work-ca.pem, cert-pass-flags = 1, remote = vpn.example.nl:1194:udp, username = secretuser\n'
  printf 'IP4.ADDRESS[1]:10.8.32.94/32\nIP4.DNS[1]:10.8.32.1\n'
  printf 'IP4.ROUTE[1]:dst = 10.8.32.93/32\nIP4.ROUTE[2]:dst = 10.8.32.1/32\nIP4.ROUTE[3]:dst = 10.25.160.0/24\nIP4.ROUTE[4]:dst = 10.100.0.0/16\n' ;;
esac
STUB
stub ip <<'STUB'
#!/usr/bin/env bash
echo '[{"ifname":"enp1","addr_info":[{"local":"192.168.2.7"}]},{"ifname":"tun0","addr_info":[{"local":"10.8.32.94"}]}]'
STUB
stub pgrep <<'STUB'
#!/usr/bin/env bash
exit 1
STUB

out=$(env -i PATH="$sandbox/path" bash "$ROOT/bin/desktop-vpn-details")

check "only VPNs are listed, not the wired profile" test "$(jq -r '[.[].name] | join(" ")' <<<"$out")" = work
check "the server is the host alone" test "$(jq -r '.[0].server' <<<"$out")" = vpn.example.nl
check "nothing else from vpn.data comes out" lacks -E "cert|secretuser|SHA256|pem" <<<"$out"
check "a split tunnel is split, and its own host routes are not counted" \
  test "$(jq -c '.[0] | [.full, .routes]' <<<"$out")" = '[false,2]'
check "the device is the one holding the tunnel's address" test "$(jq -r '.[0].iface' <<<"$out")" = tun0
check "DNS through the tunnel is named" test "$(jq -c '.[0].dns' <<<"$out")" = '["10.8.32.1"]'

finish
