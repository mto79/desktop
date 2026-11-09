#!/usr/bin/env bash
# kubectl was fetched once from "stable" and never again. What is checked: it follows one
# minor version, it is verified before it is installed, and a dl.k8s.io that is away does
# not fail the update it is part of. curl is a stub serving a directory; the "kubectl" is a
# script that says a version.
source "$(dirname "$0")/lib.sh"

UPDATE="$ROOT/bin/desktop-update-kubectl"
sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
site="$sandbox/site" stubs="$sandbox/stubs"
mkdir -p "$site" "$stubs" "$sandbox/bin"

arch=amd64
[[ $(uname -m) == aarch64 ]] && arch=arm64

# release <version>: what stable-1.35 points at, with the binary and its checksum.
release() {
  local dir="$site/release/v$1/bin/linux/$arch"
  mkdir -p "$dir"
  printf '#!/usr/bin/env bash\necho "Client Version: v%s"\n' "$1" >"$dir/kubectl"
  sha256sum "$dir/kubectl" | awk '{ print $1 }' >"$dir/kubectl.sha256"
  echo "v$1" >"$site/release/stable-1.35.txt"
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
file="$site/\${url#https://dl.k8s.io/}"
[[ -f \$file ]] || exit 22
if [[ -n \$out ]]; then cp "\$file" "\$out"; else cat "\$file"; fi
STUB
printf '#!/usr/bin/env bash\nprintf "%%s|" "$@" >>"%s/notified"; echo >>"%s/notified"\n' "$sandbox" "$sandbox" >"$stubs/notify-send"
chmod +x "$stubs"/*

run() { PATH="$stubs:$PATH" DESKTOP_KUBECTL_TARGET="$sandbox/bin/kubectl" bash "$UPDATE" "$@"; }
version() { "$sandbox/bin/kubectl" 2>/dev/null | sed 's/^Client Version: //'; }

release 1.35.10
run >/dev/null 2>&1
check "with no kubectl there, the channel's current release is installed" test "$(version)" = v1.35.10
check "from the pinned minor version" grep -q 'release/stable-1.35.txt' "$sandbox/urls"
check "and never from stable" lacks 'release/stable.txt' "$sandbox/urls"
check "an install is said on the desktop" grep -q 'kubectl updated|not installed → v1.35.10' "$sandbox/notified"

: >"$sandbox/urls"
: >"$sandbox/notified"
run >/dev/null 2>&1
check "a current kubectl is not downloaded again" lacks '/kubectl$' "$sandbox/urls"
check "and nothing is said" test ! -s "$sandbox/notified"

release 1.35.11
check "--check says what there is and what is current" \
  test "$(run --check | grep -c -e 'installed: v1.35.10' -e 'current:   v1.35.11')" = 2
check "and changes nothing" test "$(version)" = v1.35.10
run >/dev/null 2>&1
check "a newer patch release replaces it" test "$(version)" = v1.35.11
: >"$sandbox/notified"

release 1.35.12
echo 0000000000000000000000000000000000000000000000000000000000000000 \
  >"$site/release/v1.35.12/bin/linux/$arch/kubectl.sha256"
run >/dev/null 2>&1 && status=0 || status=$?
check "a download that does not match its checksum is refused" test "$status" != 0
check "and the kubectl that was there is left alone" test "$(version)" = v1.35.11
check "with nothing said" test ! -s "$sandbox/notified"

touch "$sandbox/offline"
run >/dev/null 2>&1 && status=0 || status=$?
check "dl.k8s.io out of reach does not fail the update" test "$status" = 0
check "and leaves kubectl as it was" test "$(version)" = v1.35.11

check "desktop-update keeps it current" grep -qx 'desktop-update-kubectl' "$ROOT/bin/desktop-update"
check "and a clean install uses the same script" grep -q 'desktop-update-kubectl' "$ROOT/install/packaging/kubectl.sh"

finish
