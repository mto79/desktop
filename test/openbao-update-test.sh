#!/usr/bin/env bash
# The OpenBao client holds the tokens to everything it unseals. What is checked: it follows
# one minor version, never a prerelease, a draft or the next minor; checksums.txt is believed
# only when OpenBao's key -- here a key made for the test, standing in for it -- signed it;
# the archive must match it; and GitHub being away does not fail the update it is part of.
#
# curl is a stub serving a directory, and the bao in each archive is a script that says a
# version. Nothing here reaches the network or /usr/local/bin.
source "$(dirname "$0")/lib.sh"

for tool in gpg jq; do require "$tool" || finish; done

UPDATE="$ROOT/bin/desktop-update-openbao"
sandbox=$(mktemp -d)
trap 'gpgconf --homedir "$sandbox/signer" --kill all 2>/dev/null; gpgconf --homedir "$sandbox/other" --kill all 2>/dev/null; rm -rf "$sandbox"' EXIT
site="$sandbox/site" stubs="$sandbox/stubs"
mkdir -p "$site" "$stubs" "$sandbox/bin"

# A signing key with a subkey that does the signing, as OpenBao's has, and another key that
# is not it. No email in the user id: this repository refuses to commit one.
key() {
  mkdir -m 0700 "$sandbox/$1"
  GNUPGHOME="$sandbox/$1" gpg --batch --quiet --passphrase '' \
    --quick-gen-key "OpenBao test $1" ed25519 cert never 2>/dev/null
  local primary
  primary=$(GNUPGHOME="$sandbox/$1" gpg --batch --with-colons --fingerprint 2>/dev/null |
    awk -F: '$1 == "fpr" { print $10; exit }')
  GNUPGHOME="$sandbox/$1" gpg --batch --quiet --passphrase '' \
    --quick-add-key "$primary" ed25519 sign never 2>/dev/null
  echo "$primary"
}
signer=$(key signer)
key other >/dev/null
GNUPGHOME="$sandbox/signer" gpg --batch --armor --export >"$site/key.asc" 2>/dev/null

# release <version> [key] [prerelease]: an archive and its signed checksums, and an entry in
# the API's list of releases.
echo '[]' >"$site/releases.json"
release() {
  local build="$sandbox/build" dir="$site/v$1"
  rm -rf "$build" && mkdir -p "$build" "$dir"
  printf '#!/usr/bin/env bash\necho "OpenBao v%s (abc), committed today"\n' "$1" >"$build/bao"
  chmod +x "$build/bao"
  tar -czf "$dir/openbao_${1}_linux_amd64.tar.gz" -C "$build" bao
  (cd "$dir" && sha256sum "openbao_${1}_linux_amd64.tar.gz" >checksums.txt)
  GNUPGHOME="$sandbox/${2:-signer}" gpg --batch --yes --quiet --detach-sign \
    -o "$dir/checksums.txt.gpgsig" "$dir/checksums.txt" 2>/dev/null
  listed "v$1" "${3:-false}"
}
listed() {
  jq --arg tag "$1" --argjson pre "$2" '[{tag_name: $tag, prerelease: $pre, draft: false}] + .' \
    "$site/releases.json" >"$site/releases.new" && mv "$site/releases.new" "$site/releases.json"
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
case "\$url" in
https://api.example/*) file="$site/releases.json" ;;
https://keys.example/*) file="$site/key.asc" ;;
*) file="$site/\${url#https://downloads.example/}" ;;
esac
[[ -f \$file ]] || exit 22
if [[ -n \$out ]]; then cp "\$file" "\$out"; else cat "\$file"; fi
STUB
chmod +x "$stubs/curl"
printf '#!/usr/bin/env bash\nprintf "%%s|" "$@" >>"%s/notified"; echo >>"%s/notified"\n' "$sandbox" "$sandbox" >"$stubs/notify-send"
chmod +x "$stubs/notify-send"

run() {
  PATH="$stubs:$PATH" DESKTOP_OPENBAO_TARGET="$sandbox/bin/bao" \
    DESKTOP_OPENBAO_API=https://api.example/releases \
    DESKTOP_OPENBAO_DOWNLOADS=https://downloads.example \
    DESKTOP_OPENBAO_KEY_URL=https://keys.example/openbao.asc \
    DESKTOP_OPENBAO_FINGERPRINT="$signer" bash "$UPDATE" "$@"
}
version() { "$sandbox/bin/bao" 2>/dev/null | sed 's/^OpenBao v\([0-9.]*\).*/\1/'; }

[[ $(uname -m) == x86_64 ]] || {
  pass "skipped, the archive here is amd64's"
  finish
}

release 2.6.5
release 2.7.2
listed v2.7.3-beta20261101 true
listed v2.8.0 false
run >/dev/null 2>&1
check "with no bao there, the pinned minor's newest release is installed" test "$(version)" = 2.7.2
check "signed by a subkey, and taken because the primary key is the one written down" \
  test -x "$sandbox/bin/bao"
check "not a prerelease" lacks 'beta' "$sandbox/urls"
check "nor the next minor version" lacks '/v2.8.0/' "$sandbox/urls"
check "an install is said on the desktop" grep -q 'bao updated|.*not installed → 2.7.2' "$sandbox/notified"

: >"$sandbox/urls"
: >"$sandbox/notified"
run >/dev/null 2>&1
check "a bao that is current is not downloaded again" lacks '.tar.gz' "$sandbox/urls"
check "and nothing is said when nothing changed" test ! -s "$sandbox/notified"

release 2.7.4
check "--check says what there is and what is current" \
  test "$(run --check | grep -c -e 'installed: 2.7.2' -e 'current:   2.7.4')" = 2
check "and changes nothing" test "$(version)" = 2.7.2
run >/dev/null 2>&1
check "a newer patch release replaces the one installed" test "$(version)" = 2.7.4
: >"$sandbox/notified"

release 2.7.5 other
run >/dev/null 2>&1 && status=0 || status=$?
check "checksums signed by any other key are refused" test "$status" != 0
check "and the bao that was there is left alone" test "$(version)" = 2.7.4

release 2.7.6
echo "0000000000000000000000000000000000000000000000000000000000000000  openbao_2.7.6_linux_amd64.tar.gz" \
  >"$site/v2.7.6/checksums.txt"
GNUPGHOME="$sandbox/signer" gpg --batch --yes --quiet --detach-sign \
  -o "$site/v2.7.6/checksums.txt.gpgsig" "$site/v2.7.6/checksums.txt" 2>/dev/null
run >/dev/null 2>&1 && status=0 || status=$?
check "an archive that does not match its signed checksum is refused" test "$status" != 0
check "and the bao that was there is still left alone" test "$(version)" = 2.7.4
check "with no notification of an update that did not happen" test ! -s "$sandbox/notified"

touch "$sandbox/offline"
run >/dev/null 2>&1 && status=0 || status=$?
check "GitHub out of reach does not fail the update" test "$status" = 0
check "and leaves bao as it was" test "$(version)" = 2.7.4

check "desktop-update keeps it current" grep -qx 'desktop-update-openbao' "$ROOT/bin/desktop-update"
check "and a clean install uses the same script" grep -q 'desktop-update-openbao' "$ROOT/install/packaging/openbao.sh"
check "not Fedora's openbao package any more" lacks 'dnf install' "$ROOT/install/packaging/openbao.sh"

finish
