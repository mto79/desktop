#!/usr/bin/env bash
# Packer builds the golden images and holds cloud and hypervisor credentials while it does;
# a Vault client holds the tokens to everything else. What is checked, on Packer and again on
# Vault: each follows one minor version, never a beta, an enterprise build or the next minor;
# the list of checksums is believed only when HashiCorp's key -- here a key made for the
# test, standing in for it -- signed it; the archive must match the list; and a release site
# that is away does not fail the update it is part of.
#
# curl is a stub serving a directory, and the binary in each archive is a script that says
# a version. Nothing here reaches the network or /usr/local/bin.
source "$(dirname "$0")/lib.sh"

for tool in gpg unzip zip jq; do require "$tool" || finish; done

UPDATE="$ROOT/bin/desktop-update-hashicorp"
sandbox=$(mktemp -d)
trap 'gpgconf --homedir "$sandbox/signer" --kill all 2>/dev/null; gpgconf --homedir "$sandbox/other" --kill all 2>/dev/null; rm -rf "$sandbox"' EXIT
site="$sandbox/site" stubs="$sandbox/stubs"
mkdir -p "$site" "$stubs" "$sandbox/bin"

# A signing key for the release site, and another that is not it. No email in the user id:
# this repository refuses to commit one.
key() {
  mkdir -m 0700 "$sandbox/$1"
  GNUPGHOME="$sandbox/$1" gpg --batch --quiet --passphrase '' \
    --quick-gen-key "Packer test $1" ed25519 sign never 2>/dev/null
  GNUPGHOME="$sandbox/$1" gpg --batch --with-colons --fingerprint 2>/dev/null |
    awk -F: '$1 == "fpr" { print $10; exit }'
}
signer=$(key signer)
key other >/dev/null
GNUPGHOME="$sandbox/signer" gpg --batch --armor --export >"$site/key.asc" 2>/dev/null

# release [product] <version> [key]: an archive with its checksum list, signed, and listed in
# the product's index. Packer unless another is named.
release() {
  local product=packer
  [[ $1 == vault ]] && { product=vault; shift; }
  local build="$sandbox/build" dir="$site/$product/$1"
  rm -rf "$build" && mkdir -p "$build" "$dir"
  printf '#!/usr/bin/env bash\necho "%s v%s (abc), built today"\n' "${product^}" "$1" >"$build/$product"
  chmod +x "$build/$product"
  (cd "$build" && zip -q "$dir/${product}_${1}_linux_amd64.zip" "$product")
  (cd "$dir" && sha256sum "${product}_${1}_linux_amd64.zip" >"${product}_${1}_SHA256SUMS")
  GNUPGHOME="$sandbox/${2:-signer}" gpg --batch --yes --quiet --detach-sign \
    -o "$dir/${product}_${1}_SHA256SUMS.sig" "$dir/${product}_${1}_SHA256SUMS" 2>/dev/null
  index "$product" "$1"
}
# Each index lists every version there is, betas and the next minor among them.
index() {
  mkdir -p "$site/$1"
  echo "$2" >>"$site/$1/versions"
  jq -R . "$site/$1/versions" | jq -s '{versions: (map({(.): {}}) | add)}' >"$site/$1/index.json"
}

cat >"$stubs/curl" <<STUB
#!/usr/bin/env bash
out="" url=""
while ((\$#)); do
  case "\$1" in
  -o) out=\$2; shift ;;
  --max-time) shift ;;
  http*) url=\$1 ;;
  esac
  shift
done
echo "\$url" >>"$sandbox/urls"
[[ -e "$sandbox/offline" ]] && exit 6
file="$site/\${url#https://releases.example/}"
[[ \$url == https://keys.example/* ]] && file="$site/key.asc"
[[ -f \$file ]] || exit 22
if [[ -n \$out ]]; then cp "\$file" "\$out"; else cat "\$file"; fi
STUB
chmod +x "$stubs/curl"
printf '#!/usr/bin/env bash\nprintf "%%s|" "$@" >>"%s/notified"; echo >>"%s/notified"\n' "$sandbox" "$sandbox" >"$stubs/notify-send"
chmod +x "$stubs/notify-send"

# run [product] [--check]: Packer unless another is named.
run() {
  local product=packer
  [[ ${1:-} == vault ]] && { product=vault; shift; }
  PATH="$stubs:$PATH" DESKTOP_PACKER_TARGET="$sandbox/bin/packer" \
    DESKTOP_VAULT_TARGET="$sandbox/bin/vault" \
    DESKTOP_HASHICORP_RELEASES=https://releases.example \
    DESKTOP_HASHICORP_KEY_URL=https://keys.example/pgp-key.txt \
    DESKTOP_HASHICORP_FINGERPRINT="$signer" bash "$UPDATE" "$product" "$@"
}
version() { "$sandbox/bin/${1:-packer}" 2>/dev/null | sed 's/^[A-Za-z]* v\([0-9.]*\).*/\1/'; }

[[ $(uname -m) == x86_64 ]] || {
  pass "skipped, the archive here is amd64's"
  finish
}

release 1.16.2
index packer 1.16.3-rc1
index packer 1.17.0
run >/dev/null 2>&1
check "with no packer there, the pinned minor's newest release is installed" test "$(version)" = 1.16.2
check "not a release candidate of the next patch" lacks '1.16.3-rc1' "$sandbox/urls"
check "nor the next minor version" lacks '/1.17.0/' "$sandbox/urls"
check "an install is said on the desktop" grep -q 'packer updated|.*not installed → 1.16.2' "$sandbox/notified"

: >"$sandbox/urls"
: >"$sandbox/notified"
run >/dev/null 2>&1
check "a packer that is current is not downloaded again" lacks '.zip' "$sandbox/urls"
check "and nothing is said when nothing changed" test ! -s "$sandbox/notified"

release 1.16.4
check "--check says what there is and what is current" \
  test "$(run --check | grep -c -e 'installed: 1.16.2' -e 'current:   1.16.4')" = 2
check "and changes nothing" test "$(version)" = 1.16.2
run >/dev/null 2>&1
check "a newer patch release replaces the one installed" test "$(version)" = 1.16.4
check "and the notification names both versions" grep -q '1.16.2 → 1.16.4' "$sandbox/notified"
: >"$sandbox/notified"

# A list of checksums signed by some other key is the case the signature exists for: whoever
# could replace the archive could replace the list beside it.
release 1.16.5 other
run >/dev/null 2>&1 && status=0 || status=$?
check "a checksum list not signed by HashiCorp's key is refused" test "$status" != 0
check "and the packer that was there is left alone" test "$(version)" = 1.16.4

release 1.16.6
echo "0000000000000000000000000000000000000000000000000000000000000000  packer_1.16.6_linux_amd64.zip" \
  >"$site/packer/1.16.6/packer_1.16.6_SHA256SUMS"
GNUPGHOME="$sandbox/signer" gpg --batch --yes --quiet --detach-sign \
  -o "$site/packer/1.16.6/packer_1.16.6_SHA256SUMS.sig" "$site/packer/1.16.6/packer_1.16.6_SHA256SUMS" 2>/dev/null
run >/dev/null 2>&1 && status=0 || status=$?
check "an archive that does not match its signed checksum is refused" test "$status" != 0
check "and the packer that was there is still left alone" test "$(version)" = 1.16.4
check "with no notification of an update that did not happen" test ! -s "$sandbox/notified"

# Vault the same way, from its own index, which lists enterprise builds besides the rest.
release vault 2.2.1
index vault 2.2.2+ent
index vault 2.3.0
run vault >/dev/null 2>&1
check "vault is installed at its own pinned minor's newest" test "$(version vault)" = 2.2.1
check "not an enterprise build" lacks '+ent' "$sandbox/urls"
check "nor the next minor" lacks '/vault/2.3.0/' "$sandbox/urls"
check "and installing it leaves packer as it was" test "$(version)" = 1.16.4
check "a product it does not know is refused" test "$(bash "$UPDATE" nope 2>/dev/null; echo $?)" = 2

touch "$sandbox/offline"
run >/dev/null 2>&1 && status=0 || status=$?
check "a release site that cannot be reached does not fail the update" test "$status" = 0
check "and leaves packer as it was" test "$(version)" = 1.16.4

check "desktop-update keeps packer current" grep -qx 'desktop-update-hashicorp packer' "$ROOT/bin/desktop-update"
check "and vault" grep -qx 'desktop-update-hashicorp vault' "$ROOT/bin/desktop-update"
check "and a clean install uses the same script for both" \
  grep -qF 'desktop-update-hashicorp" packer' "$ROOT/install/packaging/packer.sh"
check "vault included" grep -qF 'desktop-update-hashicorp" vault' "$ROOT/install/packaging/vault.sh"

finish
