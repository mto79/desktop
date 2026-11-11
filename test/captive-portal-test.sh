#!/usr/bin/env bash
# A network that holds you at a login page -- a hotel's, a train's. What is checked: the
# page opened is NetworkManager's own plain-HTTP check address, the request a portal is
# known to catch; never an HTTPS one, which a portal cannot answer for; a fixed fallback
# when there is none; NetworkManager is given an address to check at all, on a clean install
# and on this machine; and the bar and the panel show the state.
#
# busctl and the browser are stubs.
source "$(dirname "$0")/lib.sh"

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
stubs="$sandbox/stubs"
mkdir -p "$stubs"

cat >"$stubs/busctl" <<STUB
#!/usr/bin/env bash
cat "$sandbox/uri" 2>/dev/null || exit 1
STUB
cat >"$stubs/desktop-launch-browser" <<STUB
#!/usr/bin/env bash
echo "\$*" >"$sandbox/opened"
STUB
chmod +x "$stubs/busctl" "$stubs/desktop-launch-browser"

portal() { PATH="$stubs:$PATH" bash "$ROOT/bin/desktop-captive-portal" "$@"; }

echo 's "http://fedoraproject.org/static/hotspot.txt"' >"$sandbox/uri"
check "the page opened is NetworkManager's check address" \
  test "$(portal --url)" = http://fedoraproject.org/static/hotspot.txt
portal
check "in the browser" test "$(cat "$sandbox/opened")" = http://fedoraproject.org/static/hotspot.txt

echo 's "https://check.example/ok"' >"$sandbox/uri"
check "an HTTPS check address is not used: the portal cannot answer for it" \
  test "$(portal --url)" = http://neverssl.com/

echo 's ""' >"$sandbox/uri"
check "with no check address, a page made for this" test "$(portal --url)" = http://neverssl.com/
rm "$sandbox/uri"
check "and with NetworkManager not answering at all" test "$(portal --url)" = http://neverssl.com/

check "a clean install gives NetworkManager an address to check" \
  grep -qx 'NetworkManager-config-connectivity-fedora' "$ROOT/install/desktop-base.packages"
check "and so does a migration on a machine already installed" \
  grep -lq 'dnf install -y NetworkManager-config-connectivity-fedora' "$ROOT"/migrations/*.sh

check "the bar's network icon warns" grep -q 'NetworkConnectivity.Portal' "$ROOT/shell/Bar/widgets/Network.qml"
check "and the panel opens the page" grep -q '"desktop-captive-portal"' "$ROOT/shell/Bar/panels/NetworkPanel.qml"

finish
