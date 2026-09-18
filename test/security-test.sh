#!/usr/bin/env bash
# desktop-security's judgement, with the machine left out of it.
#
# Three things that decide whether a finding is true and whether you hear about it:
# a port counts as exposed only when the firewall admits it -- compared as numbers, since
# as strings "8080" is not inside "1025-65535"; a change is reported against what the last
# run recorded, and the first run only records; and a finding is announced once, not every
# fifteen minutes, and again only after it has gone away and come back.
source "$(dirname "$0")/lib.sh"

require jq || finish

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
export XDG_STATE_HOME=$sandbox/state

# The script's functions without its checks running: everything above the output section,
# and notify from within it.
eval "$(sed -n '1,/^# -* output$/p' "$ROOT/bin/desktop-security")"
eval "$(sed -n '/^notify() {$/,/^}$/p' "$ROOT/bin/desktop-security")"

allowed_ports=$'1025-65535/tcp\n22/tcp ssh\n5353/udp mdns\n'
check "a service's port is admitted by the service" test "$(admitted 22 tcp)" = ssh
check "a port inside a range is admitted by the range" test "$(admitted 8080 tcp)" = 1025-65535
check "a port below the range is not" test -z "$(admitted 80 tcp)"
check "the protocol has to match" test -z "$(admitted 22 udp)"

# Reading a zone's ports is firewalld's config.info, which polkit meets with a password
# or fingerprint prompt -- four an hour, from the timer, until the check learned to ask
# pkcheck first. Without the permission no zone may be read, and the listener check may
# not claim nothing is reachable, having looked at nothing.
mkdir -p "$sandbox/fw"
cat >"$sandbox/fw/systemctl" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
cat >"$sandbox/fw/pkcheck" <<STUB
#!/usr/bin/env bash
[ -e "$sandbox/allowed" ]
STUB
cat >"$sandbox/fw/firewall-cmd" <<STUB
#!/usr/bin/env bash
echo "\$*" >>"$sandbox/firewall-calls"
[[ "\$*" == --get-active-zones ]] && printf 'public (default)\n  interfaces: eth0\n'
[[ "\$*" == *--list-all* ]] && printf 'public\n  target: default\n  services: ssh\n  ports: \n'
exit 0
STUB
chmod +x "$sandbox/fw/"*
findings=() passed=() allowed_ports="" firewall_readable=true
PATH="$sandbox/fw:$PATH" check_firewall
check "without the permission, no zone's contents are asked for" lacks -- "--list-all" "$sandbox/firewall-calls"
check "and it says the ports were not checked" test "$(jq -r .id <<<"${findings[0]}")" = firewall-unread
PATH="$sandbox/fw:$PATH" check_exposed
check "and the listeners are not declared unreachable" lacks "Nothing listening" <<<"${passed[*]}"
touch "$sandbox/allowed"
findings=() passed=() allowed_ports="" firewall_readable=true
PATH="$sandbox/fw:$PATH" check_firewall
check "with the permission, the zone is read" grep -q -- "--list-all" "$sandbox/firewall-calls"
check "and its services count as admitted" test "$(admitted 22 tcp)" = ssh

findings=()
watch_list startup $'/etc/systemd/system/a.service\n/home/u/.config/autostart/b.desktop' "New startup items" "accept"
check "the first run records, and reports nothing" test ${#findings[@]} = 0
watch_list startup $'/etc/systemd/system/a.service\n/home/u/.config/autostart/b.desktop\n/home/u/.config/systemd/user/evil.timer' "New startup items" "accept"
check "an item added since is a finding" test "$(jq -r .detail <<<"${findings[0]}")" = "/home/u/.config/systemd/user/evil.timer."
findings=()
watch_list startup $'/etc/systemd/system/a.service' "New startup items" "accept"
check "an item removed is not" test ${#findings[@]} = 0

findings=()
add ssh-exposed warn "SSH is open" "port 22"
add ssh-exposed warn "SSH is open" "port 22 again, over IPv6"
check "one finding per id, however many sockets report it" test ${#findings[@]} = 1

mkdir -p "$sandbox/bin"
printf '#!/usr/bin/env bash\necho "$*" >>"%s/notified.log"\n' "$sandbox" >"$sandbox/bin/notify-send"
chmod +x "$sandbox/bin/notify-send"
PATH="$sandbox/bin:$PATH"
result() { jq -nc --argjson ids "$1" '{findings: ($ids | map({id: ., level: "warn", title: ("t-" + .), detail: "d"})) + [{id: "quiet", level: "info", title: "info", detail: "d"}]}'; }
count() { [[ -f $sandbox/notified.log ]] && grep -c . "$sandbox/notified.log" || echo 0; }

notify "$(result '["a"]')"
check "a new finding is announced" test "$(count)" = 1
notify "$(result '["a"]')"
check "and not again on the next run" test "$(count)" = 1
notify "$(result '["a", "b"]')"
check "a second finding is announced on its own" test "$(count)" = 2
check "info findings are never announced" lacks "info" "$sandbox/notified.log"
notify "$(result '["b"]')"
notify "$(result '["a", "b"]')"
check "a finding that went away and came back is announced again" test "$(count)" = 3

finish
