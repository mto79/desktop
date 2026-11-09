#!/usr/bin/env bash
# The directories tools keep credentials in. kubectl left ~/.kube/config 0644 and ~/.aws 0755,
# and nothing made ~/.config/tofu at all. What is checked: a tool that is installed gets its
# directory, one others can read is put back, a file kept tighter is not loosened, --check
# changes nothing, and install and update both run it.
source "$(dirname "$0")/lib.sh"

UPDATE="$ROOT/bin/desktop-update-secrets"
sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
home="$sandbox/home"
mkdir -p "$sandbox/stubs" "$sandbox/none" "$home"
for tool in tofu kubectl; do
  printf '#!/usr/bin/env bash\n' >"$sandbox/stubs/$tool"
  chmod +x "$sandbox/stubs/$tool"
done

run() { DESKTOP_SECRETS_HOME="$home" PATH="$sandbox/stubs:/usr/bin:/bin" bash "$UPDATE" "$@"; }
mode() { stat -c %a "$1"; }
# check cannot take a `!`: this is "the check failed, and said so".
happy() { run --check >/dev/null; }
refuses() { ! run --check >"$sandbox/said" && grep -q "$1" "$sandbox/said"; }

check "--check says a missing tofu directory is missing" refuses "tofu: missing"
check "and does not make it" test ! -d "$home/.config/tofu"

run >/dev/null
check "made when tofu is installed" test -d "$home/.config/tofu"
check "owner-only" test "$(mode "$home/.config/tofu")" = 700
check "~/.kube made when kubectl is installed" test "$(mode "$home/.kube")" = 700
check "nothing made for a tool with nothing there" test ! -e "$home/.aws"
check "--check is happy after" happy

# The state this machine was found in.
chmod 755 "$home/.kube"
printf 'x\n' >"$home/.kube/config"
chmod 644 "$home/.kube/config"
mkdir -p "$home/.aws/cli/cache"
chmod 755 "$home/.aws"
printf 'x\n' >"$home/.aws/credentials"
chmod 400 "$home/.aws/credentials"
check "--check names a config others can read" refuses "kube/config: mode 644"
check "and the directory" refuses "kube: mode 755"
check "and leaves them alone" test "$(mode "$home/.kube/config")" = 644

run >/dev/null
check "the kube config is put back to 600" test "$(mode "$home/.kube/config")" = 600
check "its directory to 700" test "$(mode "$home/.kube")" = 700
check "~/.aws to 700" test "$(mode "$home/.aws")" = 700
check "a credentials file kept at 400 is not loosened" test "$(mode "$home/.aws/credentials")" = 400
check "what is in them is untouched" grep -qx x "$home/.kube/config"

rm -rf "$home"
mkdir -p "$home"
DESKTOP_SECRETS_HOME="$home" PATH="$sandbox/none" /usr/bin/bash "$UPDATE" >/dev/null
check "no tools, nothing made" test -z "$(ls -A "$home")"

check "desktop-update runs it" grep -qx 'desktop-update-secrets' "$ROOT/bin/desktop-update"
check "a clean install runs it after tofu" grep -q 'desktop-update-secrets' "$ROOT/install/packaging/opentofu.sh"
check "and after kubectl" grep -q 'desktop-update-secrets' "$ROOT/install/packaging/kubectl.sh"

finish
