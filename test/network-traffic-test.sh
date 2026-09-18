#!/usr/bin/env bash
# desktop-network-traffic, with tshark, ss and the group lookups faked.
#
# What is checked is the reading, not the capturing: which name an address gets when the
# traffic offers two (the TLS handshake's beats DNS's, and a reverse lookup only fills a
# gap); which end of a packet is the remote one; who owns a socket written the IPv4-mapped
# way; TLS counted once under its three names; and the three states capture permission
# can be in -- including a group added since login, which sg has to cover.
source "$(dirname "$0")/lib.sh"

require jq || finish

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
mkdir -p "$sandbox/path" "$sandbox/runtime"
for tool in bash env jq awk sort head paste timeout mktemp chmod rm cat grep tr cut sleep kill sed touch; do
  ln -s "$(command -v "$tool")" "$sandbox/path/$tool"
done

stub() {
  cat >"$sandbox/path/$1"
  chmod +x "$sandbox/path/$1"
}

stub ip <<'STUB'
#!/usr/bin/env bash
case "$*" in
*route*) echo '[{"dst":"default","dev":"eth9","metric":100}]' ;;
*addr*) echo '[{"addr_info":[{"local":"192.168.2.7"},{"local":"127.0.0.1"}]}]' ;;
esac
STUB

# A capture writes a file; reading it back answers by what was asked for.
stub tshark <<'STUB'
#!/usr/bin/env bash
case "$*" in
*"-i "*)
  while (($#)); do [[ $1 == -w ]] && { echo pcap >"$2"; exit 0; }; shift; done ;;
*tls.handshake.type*) printf '140.82.121.4\t\tgithub.com\n' ;;
*dns.flags.response*)
  printf 'not-github.example\t140.82.121.4\t\n'
  printf 'example.org\t93.184.216.34,93.184.216.35\t\n' ;;
*)
  printf '192.168.2.7\t140.82.121.4\t\t\t1000\tTLSv1.3\n'
  printf '140.82.121.4\t192.168.2.7\t\t\t3000\tTLSv1.2\n'
  printf '192.168.2.7\t93.184.216.34\t\t\t500\tSSL\n'
  printf '192.168.2.7\t8.8.8.8\t\t\t100\tDNS\n' ;;
esac
STUB

stub ss <<'STUB'
#!/usr/bin/env bash
echo 'tcp ESTAB 0 0 192.168.2.7:5555 140.82.121.4:443 users:(("brave",pid=1,fd=3))'
echo 'tcp ESTAB 0 0 [::ffff:192.168.2.7]:5556 [::ffff:93.184.216.34]:443 users:(("curl",pid=2,fd=3))'
STUB

stub getent <<'STUB'
#!/usr/bin/env bash
case "$1 $2" in
"group wireshark") echo "wireshark:x:967:$ETC_MEMBERS" ;;
"hosts 8.8.8.8") echo "8.8.8.8 dns.google" ;;
*) exit 2 ;;
esac
STUB
stub id <<'STUB'
#!/usr/bin/env bash
echo "$PROCESS_GROUPS"
STUB
stub sg <<'STUB'
#!/usr/bin/env bash
touch "$SANDBOX/used-sg"
[[ $2 == -c ]] && exec bash -c "$3"
STUB

traffic() {
  env -i PATH="$sandbox/path" USER=mto SANDBOX="$sandbox" XDG_RUNTIME_DIR="$sandbox/runtime" \
    PROCESS_GROUPS="$1" ETC_MEMBERS="$2" bash "$ROOT/bin/desktop-network-traffic" --seconds 1
}

out=$(traffic "mto wheel wireshark" "mto")
host() { jq -c --arg ip "$1" '.hosts[] | select(.ip == $ip) | [.name, .process, .bytes]' <<<"$out"; }

check "a capture reads back into a summary" test "$(jq -r '"\(.iface) \(.bytes) \(.packets)"' <<<"$out")" = "eth9 4600 4"
check "the busiest host is first, both directions counted" test "$(jq -r '.hosts[0].ip' <<<"$out")" = 140.82.121.4
check "the handshake's name beats the DNS answer's" test "$(host 140.82.121.4)" = '["github.com","brave",4000]'
check "a DNS answer names what no handshake did" test "$(host 93.184.216.34)" = '["example.org","curl",500]'
check "an owner written the IPv4-mapped way is still found" grep -q curl <<<"$(host 93.184.216.34)"
check "a reverse lookup fills the last gap" test "$(host 8.8.8.8)" = '["dns.google",null,100]'
check "TLS is counted once, whatever tshark calls it" \
  test "$(jq -c '.protocols' <<<"$out")" = '[{"name":"TLS","bytes":4500},{"name":"DNS","bytes":100}]'
check "with the group, capture runs directly" test ! -e "$sandbox/used-sg"

out=$(traffic "mto wheel" "mto")
check "a group added since login is used through sg" test -e "$sandbox/used-sg"
check "and the capture still works" test "$(jq -r '.hosts | length' <<<"$out")" = 3

check "without the group anywhere, it says so" test "$(traffic "mto wheel" "" | jq -r .error)" = permission

rm "$sandbox/path/tshark"
check "without tshark, it says that instead" test "$(traffic "mto" "mto" | jq -r .error)" = missing

finish
