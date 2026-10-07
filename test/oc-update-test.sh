#!/usr/bin/env bash
# The OpenShift client is a binary from a mirror that will hold cluster-admin tokens, and
# for nine months it was whatever "latest" had meant on the day of the install. What is
# checked: it follows one minor version, it is verified before it is installed, and a
# mirror that is away does not fail the update it is part of.
#
# curl is a stub serving a directory, and the "oc" in the archive is a script that says a
# version. Nothing here reaches the network or /usr/local/bin.
source "$(dirname "$0")/lib.sh"

UPDATE="$ROOT/bin/desktop-update-oc"
sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
mirror="$sandbox/mirror" stubs="$sandbox/stubs"
mkdir -p "$mirror" "$stubs" "$sandbox/bin"

# release <version>: what the channel points at, archive and checksum and all.
release() {
  local build="$sandbox/build"
  rm -rf "$build" && mkdir -p "$build"
  printf '#!/usr/bin/env bash\necho "Client Version: %s"\n' "$1" >"$build/oc"
  printf '#!/usr/bin/env bash\necho not-wanted\n' >"$build/kubectl"
  chmod +x "$build"/*
  tar -czf "$mirror/openshift-client-linux.tar.gz" -C "$build" oc kubectl
  printf 'Name:           %s\n' "$1" >"$mirror/release.txt"
  (cd "$mirror" && sha256sum openshift-client-linux.tar.gz >sha256sum.txt)
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
file="$mirror/\${url##*/}"
[[ -f \$file ]] || exit 22
if [[ -n \$out ]]; then cp "\$file" "\$out"; else cat "\$file"; fi
STUB
chmod +x "$stubs/curl"
printf '#!/usr/bin/env bash\nprintf "%%s|" "$@" >>"%s/notified"; echo >>"%s/notified"\n' "$sandbox" "$sandbox" >"$stubs/notify-send"
chmod +x "$stubs/notify-send"

run() { PATH="$stubs:$PATH" DESKTOP_OC_TARGET="$sandbox/bin/oc" bash "$UPDATE" "$@"; }
version() { "$sandbox/bin/oc" 2>/dev/null | sed 's/^Client Version: //'; }

release 4.22.16
run >/dev/null 2>&1
check "with no oc there, the channel's current release is installed" test "$(version)" = 4.22.16
check "from the pinned minor version, not from latest" grep -q '/ocp/stable-4.22/' "$sandbox/urls"
check "and never from latest" lacks '/ocp/latest/' "$sandbox/urls"
check "the kubectl in the archive is left in it" test ! -e "$sandbox/bin/kubectl"
check "an install is said on the desktop" grep -q 'oc updated|.*not installed → 4.22.16' "$sandbox/notified"

: >"$sandbox/urls"
: >"$sandbox/notified"
run >/dev/null 2>&1
check "an oc that is current is not downloaded again" lacks 'tar.gz' "$sandbox/urls"
check "and nothing is said when nothing changed" test ! -s "$sandbox/notified"

release 4.22.17
check "--check says what there is and what is current" \
  test "$(run --check | grep -c -e 'installed: 4.22.16' -e 'current:   4.22.17')" = 2
check "and changes nothing" test "$(version)" = 4.22.16
run >/dev/null 2>&1
check "a newer patch release replaces the one installed" test "$(version)" = 4.22.17
check "and the notification names both versions" grep -q '4.22.16 → 4.22.17' "$sandbox/notified"
: >"$sandbox/notified"

# The archive and the list of checksums disagreeing is the case the check exists for.
release 4.22.18
echo "0000000000000000000000000000000000000000000000000000000000000000  openshift-client-linux.tar.gz" >"$mirror/sha256sum.txt"
run >/dev/null 2>&1 && status=0 || status=$?
check "an archive that does not match its checksum is refused" test "$status" != 0
check "and the oc that was there is left alone" test "$(version)" = 4.22.17
check "with no notification of an update that did not happen" test ! -s "$sandbox/notified"

touch "$sandbox/offline"
run >/dev/null 2>&1 && status=0 || status=$?
check "a mirror that cannot be reached does not fail the update" test "$status" = 0
check "and leaves oc as it was" test "$(version)" = 4.22.17

check "desktop-update keeps it current" grep -qx 'desktop-update-oc' "$ROOT/bin/desktop-update"
check "and a clean install uses the same script" grep -q 'desktop-update-oc' "$ROOT/install/packaging/oc.sh"

finish
