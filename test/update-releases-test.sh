#!/usr/bin/env bash
# helm, lazygit, kubie and the aws cli were fetched once and never again, kubie with nothing
# checked. What is checked: what is installed is updated and nothing else, every download is
# held to its checksum, a tool named is installed, and nothing out of reach fails the update.
# curl is a stub serving a directory laid out by URL; the tools are scripts that say a version.
source "$(dirname "$0")/lib.sh"

UPDATE="$ROOT/bin/desktop-update-releases"
sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
site="$sandbox/site" stubs="$sandbox/stubs" bin="$sandbox/bin"
mkdir -p "$site" "$stubs" "$bin" "$sandbox/desktop/install/packaging"

arch=amd64 longarch=x86_64
[[ $(uname -m) == aarch64 ]] && arch=arm64 longarch=arm64

cat >"$stubs/curl" <<STUB
#!/usr/bin/env bash
out="" url=""
while ((\$#)); do
  case "\$1" in
  -o) out=\$2; shift ;;
  --max-time|-H) shift ;;
  http*) url=\$1 ;;
  esac
  shift
done
echo "\$url" >>"$sandbox/urls"
[[ -e "$sandbox/offline" ]] && exit 6
file="$site/\${url#https://}"
[[ -f \$file ]] || exit 22
if [[ -n \$out ]]; then cp "\$file" "\$out"; else cat "\$file"; fi
STUB
printf '#!/usr/bin/env bash\nprintf "%%s|" "$@" >>"%s/notified"; echo >>"%s/notified"\n' "$sandbox" "$sandbox" >"$stubs/notify-send"
# The aws cli's own installer, which checks AWS's signature: here it only says it ran.
printf '#!/usr/bin/env bash\necho ran >>"%s/aws-installer"\n' "$sandbox" >"$sandbox/desktop/install/packaging/awscli2.sh"
chmod +x "$stubs"/*

# tool <name> <version> <file>: a script that answers the way the real one does.
tool() {
  case "$1" in
  helm) printf '#!/usr/bin/env bash\necho v%s\n' "$2" ;;
  lazygit) printf '#!/usr/bin/env bash\necho "commit=, build date=, version=%s, os=linux"\n' "$2" ;;
  kubie) printf '#!/usr/bin/env bash\necho "kubie %s"\n' "$2" ;;
  talosctl) printf '#!/usr/bin/env bash\nprintf "Client:\\n\\tTag:         v%s\\n\\tSHA:         abc\\n"\n' "$2" ;;
  aws) printf '#!/usr/bin/env bash\necho "aws-cli/%s Python/3 Linux/7 exe/x86_64"\n' "$2" ;;
  esac >"$3"
  chmod +x "$3"
}
digest() { sha256sum "$1" | awk '{ print $1 }'; }

# helm: the tag on GitHub, the archive and its .sha256sum on get.helm.sh.
helm_release() {
  local work="$sandbox/build" dir="$site/get.helm.sh"
  rm -rf "$work" && mkdir -p "$work/linux-$arch" "$dir" "$site/api.github.com/repos/helm/helm/releases"
  tool helm "$1" "$work/linux-$arch/helm"
  tar -czf "$dir/helm-v$1-linux-$arch.tar.gz" -C "$work" "linux-$arch/helm"
  echo "$(digest "$dir/helm-v$1-linux-$arch.tar.gz")  helm-v$1-linux-$arch.tar.gz" >"$dir/helm-v$1-linux-$arch.tar.gz.sha256sum"
  echo "{\"tag_name\":\"v$1\"}" >"$site/api.github.com/repos/helm/helm/releases/latest"
}
# github_release <repo> <tag> <asset name> <file> [digest]: GitHub's description of a release.
github_release() {
  local dl="$site/github.com/$1/releases/download/$2" sum=${5:-}
  mkdir -p "$dl" "$site/api.github.com/repos/$1/releases"
  cp "$4" "$dl/$3"
  [[ -n $sum ]] || sum=$(digest "$dl/$3")
  printf '{"tag_name":"%s","assets":[{"name":"%s","browser_download_url":"https://github.com/%s/releases/download/%s/%s","digest":"sha256:%s"}]}\n' \
    "$2" "$3" "$1" "$2" "$3" "$sum" >"$site/api.github.com/repos/$1/releases/latest"
}
lazygit_release() {
  local work="$sandbox/build"
  rm -rf "$work" && mkdir -p "$work"
  tool lazygit "$1" "$work/lazygit"
  tar -czf "$work/archive.tar.gz" -C "$work" lazygit
  github_release jesseduffield/lazygit "v$1" "lazygit_$1_linux_$longarch.tar.gz" "$work/archive.tar.gz" "${2:-}"
}
kubie_release() {
  tool kubie "$1" "$sandbox/kubie-build"
  github_release kubie-org/kubie "v$1" "kubie-linux-$arch" "$sandbox/kubie-build" "${2:-}"
}
talosctl_release() {
  tool talosctl "$1" "$sandbox/talosctl-build"
  github_release siderolabs/talos "v$1" "talosctl-linux-$arch" "$sandbox/talosctl-build" "${2:-}"
}
aws_release() {
  mkdir -p "$site/raw.githubusercontent.com/aws/aws-cli/v2"
  printf 'CHANGELOG\n=========\n\n%s\n=======\n' "$1" >"$site/raw.githubusercontent.com/aws/aws-cli/v2/CHANGELOG.rst"
}

run() {
  PATH="$bin:$stubs:/usr/bin:/bin" DESKTOP_RELEASES_BIN="$bin" DESKTOP_PATH="$sandbox/desktop" \
    bash "$UPDATE" "$@"
}
version() { "$bin/$1" version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1; }

helm_release 4.3.1
lazygit_release 0.66.2
kubie_release 0.28.0
talosctl_release 1.11.5
aws_release 2.39.6

run >/dev/null 2>&1
check "with nothing installed, nothing is installed" test -z "$(ls -A "$bin")"
check "or asked about" test ! -s "$sandbox/urls"

tool helm 4.1.1 "$bin/helm"
tool lazygit 0.59.0 "$bin/lazygit"
check "--check says helm is behind" grep -q 'helm 4.1.1 -> 4.3.1' <(run --check 2>&1)
check "and changes nothing" test "$(version helm)" = 4.1.1

run >"$sandbox/said" 2>&1
check "an installed helm is updated" test "$(version helm)" = 4.3.1
check "from the archive on get.helm.sh, checked against its .sha256sum" \
  grep -q 'get.helm.sh/helm-v4.3.1-linux-.*sha256sum' "$sandbox/urls"
check "lazygit too, from its GitHub asset" test "$(version lazygit)" = 0.66.2
check "a tool that is not installed is left out" test ! -e "$bin/kubie"
check "and the aws installer is not run for an aws that is not there" test ! -e "$sandbox/aws-installer"
check "each update is said on the desktop" grep -q 'helm updated|4.1.1 → 4.3.1' "$sandbox/notified"

: >"$sandbox/urls"
: >"$sandbox/notified"
run >/dev/null 2>&1
check "what is current is not downloaded again" lacks 'tar.gz$' "$sandbox/urls"
check "and nothing is said" test ! -s "$sandbox/notified"

run kubie >/dev/null 2>&1
check "a tool named is installed" test "$(version kubie)" = 0.28.0
run talosctl >/dev/null 2>&1
check "talosctl, for Talos clusters, from siderolabs' release" test "$(version talosctl)" = 1.11.5

# The digest GitHub gives and the file disagreeing: the case the check is for.
lazygit_release 0.67.0 0000000000000000000000000000000000000000000000000000000000000000
run >"$sandbox/said" 2>&1 && status=0 || status=$?
check "a download that does not match its digest is refused" grep -q 'lazygit: the download does not match' "$sandbox/said"
check "and the lazygit there is left alone" test "$(version lazygit)" = 0.66.2
check "without failing the rest of the update" test "$status" = 0
run lazygit >/dev/null 2>&1 && status=0 || status=$?
check "but an install that named it is told" test "$status" != 0

kubie_release 0.29.0 none
sed -i 's/"digest":"sha256:none"/"digest":null/' "$site/api.github.com/repos/kubie-org/kubie/releases/latest"
run >"$sandbox/said" 2>&1
check "no checksum published, nothing installed" test "$(version kubie)" = 0.28.0
check "and it says so" grep -q 'kubie: upstream publishes no checksum' "$sandbox/said"

tool aws 2.36.45 "$bin/aws"
run >/dev/null 2>&1
check "an aws behind its changelog runs AWS's own installer" test -s "$sandbox/aws-installer"

touch "$sandbox/offline"
run >"$sandbox/said" 2>&1 && status=0 || status=$?
check "upstream out of reach does not fail the update" test "$status" = 0
check "and says what it left" grep -q 'helm: could not ask upstream.*left at 4.3.1' "$sandbox/said"

check "an unknown tool is refused" bash -c "! PATH='$stubs:/usr/bin:/bin' bash '$UPDATE' nosuch 2>/dev/null"
check "desktop-update runs it" grep -qx 'desktop-update-releases' "$ROOT/bin/desktop-update"
for t in helm lazygit kubie talosctl; do
  check "a clean install of $t uses it" grep -q "desktop-update-releases\" $t" "$ROOT/install/packaging/$t.sh"
done

finish
