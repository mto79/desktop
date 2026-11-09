#!/usr/bin/env bash
# Tools pinned with a checksum in their install script never move, and nothing said when
# they could. What is checked: a newer release is named with the line to change, the same or
# an older one is not, and nothing is ever changed.
source "$(dirname "$0")/lib.sh"

UPDATE="$ROOT/bin/desktop-update-pinned"
sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
site="$sandbox/site" pack="$sandbox/packaging"
mkdir -p "$sandbox/stubs" "$pack"
cat >"$sandbox/stubs/curl" <<STUB
#!/usr/bin/env bash
for a; do [[ \$a == http* ]] && url=\$a; done
file="$site/\${url#https://}"
[[ -f \$file ]] && cat "\$file" || exit 22
STUB
chmod +x "$sandbox/stubs/curl"

pin() { printf '#!/usr/bin/env bash\n%s="%s"\n' "$2" "$3" >"$pack/$1.sh"; }
latest() { mkdir -p "$site/$1" && echo "{\"tag_name\":\"$2\"}" >"$site/$1/latest"; }

pin kubeseal KUBESEAL_VERSION 0.40.0
latest api.github.com/repos/bitnami-labs/sealed-secrets/releases v0.41.2
pin tea TEA_VERSION 0.16.0
latest gitea.com/api/v1/repos/gitea/tea/releases v0.16.0
pin tflint TFLINT_VERSION 0.65.0
latest api.github.com/repos/terraform-linters/tflint/releases v0.64.0
pin voxtype VOXTYPE_RELEASE 0.6.3
cp -r "$pack" "$sandbox/before"

PATH="$sandbox/stubs:/usr/bin:/bin" DESKTOP_PINNED_PACKAGING="$pack" bash "$UPDATE" >"$sandbox/said"
check "a newer release is named, with what to change" \
  grep -q 'kubeseal 0.40.0 -> 0.41.2 available.*bump KUBESEAL_VERSION in install/packaging/kubeseal.sh' "$sandbox/said"
check "from Gitea as well as GitHub" grep -q 'tea 0.16.0 is the newest' "$sandbox/said"
check "an older upstream is not an update" lacks 'tflint.*available' "$sandbox/said"
check "no answer is said, not taken for current" grep -q 'voxtype 0.6.3: could not ask' "$sandbox/said"
check "a script without its pin is said" grep -q 'argo9s: no ARGO9S_VERSION' "$sandbox/said"
check "and no script is changed" diff -r "$sandbox/before" "$pack"

check "every pin it knows names a variable its script has" bash -c '
  for pair in ARGO9S_VERSION:argo9s KUBESEAL_VERSION:kubeseal TEA_VERSION:tea \
    TFLINT_VERSION:tflint CONFTEST_VERSION:conftest GETEDUROAM_VERSION:geteduroam VOXTYPE_RELEASE:voxtype; do
    grep -q "^${pair%%:*}=" "'"$ROOT"'/install/packaging/${pair#*:}.sh" || exit 1
  done'
check "desktop-update runs it" grep -qx 'desktop-update-pinned' "$ROOT/bin/desktop-update"

finish
