#!/usr/bin/env bash
# A clean install has to reproduce this machine. Three ways that has failed:
# a command used everywhere and installed by nothing (jq, impala), a packaging script
# that nothing sources so it never runs, and a package name that no longer resolves --
# which fails the single dnf install and so installs nothing at all.
source "$(dirname "$0")/lib.sh"

packages="$ROOT/install/desktop-base.packages"
all="$ROOT/install/packaging/all.sh"

listed() { grep -qxF "$1" "$packages"; }

# Hard dependencies of bin/desktop-* scripts. Each earned its place by being missing.
for cmd in jq python3; do
  if listed "$cmd" || [[ $cmd == python3 ]]; then
    pass "$cmd is accounted for"
  else
    fail "$cmd is accounted for" "used by bin/desktop-* but absent from desktop-base.packages"
  fi
done

dupes=$(sort "$packages" | grep -v '^#' | grep -v '^$' | uniq -d || true)
if [[ -z $dupes ]]; then pass "no duplicate packages"; else fail "no duplicate packages" "$dupes"; fi

# Every command a bin/ script calls with a bare name should come from somewhere.
missing=()
for cmd in $(grep -rhoP '(?<![\w./-])(jq|gum|notify-send|hyprctl|grim|slurp|satty|wl-copy|brightnessctl|playerctl|fc-list)(?![\w-])' "$ROOT/bin" 2>/dev/null | sort -u); do
  listed "$cmd" && continue
  case $cmd in
    notify-send) listed libnotify && continue ;;
    wl-copy) listed wl-clipboard && continue ;;
    hyprctl) listed hyprland && continue ;;
    fc-list) listed fontconfig && continue ;;
  esac
  missing+=("$cmd")
done
if ((${#missing[@]} == 0)); then
  pass "every common command bin/ calls is in the package list"
else
  fail "every common command bin/ calls is in the package list" "${missing[*]}"
fi

# A packaging script nothing sources never runs. These four are known-unwired; the point
# of the list is that a fifth gets noticed.
known_unwired=(openshiftlocal.sh openvpn.sh stack.sh zoom.sh)
orphans=()
for f in "$ROOT"/install/packaging/*.sh; do
  b=$(basename "$f")
  [[ $b == all.sh ]] && continue
  grep -q "packaging/$b" "$all" && continue
  printf '%s\n' "${known_unwired[@]}" | grep -qxF "$b" && continue
  orphans+=("$b")
done
if ((${#orphans[@]} == 0)); then
  pass "no new unwired packaging scripts"
else
  fail "no new unwired packaging scripts" "${orphans[*]} — source from packaging/all.sh or add to known_unwired"
fi

# The reverse: all.sh naming a file that does not exist.
gone=()
while read -r b; do
  [[ -f "$ROOT/install/packaging/$b" ]] || gone+=("$b")
done < <(grep -oP '^\s*source "\$DESKTOP_INSTALL/packaging/\K[^"]+' "$all")
if ((${#gone[@]} == 0)); then pass "all.sh sources only files that exist"; else fail "all.sh sources only files that exist" "${gone[*]}"; fi

# The Hyprland copr is pinned with includepkgs, so a package the install list wants but
# the pin omits is "filtered out by exclude filtering" -- dnf then refuses the whole
# transaction without ever naming the pin as the cause. hyprwire cost an evening this
# way. Every hypr* package we ask for, plus satty, has to be in the pin.
copr="$ROOT/install/preflight/copr.sh"
pinned=$(sed -n '/^HYPR_PACKAGES=(/,/^)/p' "$copr" | sed '1d;$d' | tr ' \n' '\n\n')
unpinned=()
while read -r pkg; do
  printf '%s\n' "$pinned" | grep -qxF "$pkg" || unpinned+=("$pkg")
done < <(grep -hE '^(hypr|satty$)' "$ROOT"/install/*.packages | sort -u)
if ((${#unpinned[@]} == 0)); then
  pass "every Hyprland package we install is allowed by the copr pin"
else
  fail "every Hyprland package we install is allowed by the copr pin" \
    "${unpinned[*]} — add to HYPR_PACKAGES in install/preflight/copr.sh"
fi

# The list above only covers what we ask for by name; the pin also has to cover what
# those packages drag in, and that is where hyprwire hid. dnf knows which repo each
# installed package came from, so on a machine that already runs this stack the real
# closure can be read back and checked. Offline, and skipped elsewhere.
if have dnf; then
  missing=()
  while read -r pkg; do
    [[ -n $pkg ]] || continue
    printf '%s\n' "$pinned" | grep -qxF "$pkg" || missing+=("$pkg")
  done < <(dnf repoquery -q --installed --qf '%{name} %{from_repo}\n' 2>/dev/null \
    | awk '$2 ~ /mineiro:hyprland/ {print $1}')
  if ((${#missing[@]} == 0)); then
    pass "the copr pin covers everything actually installed from it"
  else
    fail "the copr pin covers everything actually installed from it" \
      "${missing[*]} — a reinstall would fail with 'filtered out by exclude filtering'"
  fi
else
  pass "skipped, dnf not present"
fi

# And the pin copr.sh intends has to be the pin the machine actually has. It was not:
# the repo got enabled by hand during the 0.56 upgrade and went unpinned for a day.
# Note the location -- dnf5 setopt writes to repos.override.d, never to the .repo file,
# so grepping /etc/yum.repos.d for includepkgs reports "unset" even when it is set.
override=/etc/dnf/repos.override.d/99-config_manager.repo
repoid=$(grep -oP '\bcopr:[A-Za-z0-9_.:@-]+(?=\.includepkgs)' "$copr" | head -1)
if [[ -f $override && -n $repoid ]]; then
  live=$(sed -n "\|^\[$repoid\]|,/^\[/p" "$override" | grep -m1 '^includepkgs=' | cut -d= -f2-)
  want=$(printf '%s\n' "$pinned" | grep -v '^$' | sort | paste -sd,)
  got=$(printf '%s\n' "${live//,/$'\n'}" | grep -v '^$' | sort | paste -sd,)
  if [[ -z $live ]]; then
    fail "the live copr pin matches copr.sh" "$repoid has no includepkgs — re-run install/preflight/copr.sh"
  elif [[ $want == "$got" ]]; then
    pass "the live copr pin matches copr.sh"
  else
    fail "the live copr pin matches copr.sh" "drifted — re-run install/preflight/copr.sh"
  fi
else
  pass "skipped, no dnf repo overrides on this machine"
fi

# NVIDIA rotates the CUDA repository signing key between Fedora releases -- fedora43
# publishes only 1940C73E.pub, fedora44 only 73CD9B30.pub. A key name written into a
# $releasever URL therefore 404s on the release after the one it was written for, and
# the failure surfaces as an unimportable key mid-upgrade rather than as a bad URL.
# The name has to be resolved from the repository, never hardcoded.
#
# Commented lines are skipped deliberately: nvidia.sh and the migration both name the
# two keys in prose, to explain why neither may be written into a URL. Without that the
# check flags its own documentation.
hardcoded=$(grep -rnE '[0-9A-F]{8}\.pub' "$ROOT/install" "$ROOT/migrations" 2>/dev/null |
  awk -F: '$3 !~ /^[[:space:]]*#/ {print $1}' | sort -u)
if [[ -z $hardcoded ]]; then
  pass "no install script hardcodes an NVIDIA signing key name"
else
  fail "no install script hardcodes an NVIDIA signing key name" \
    "${hardcoded//$ROOT\//} — resolve it from the repo listing instead"
fi

# nvidia.sh writes cuda-fedora-nvidia.repo, whose baseurl follows $releasever. A
# release-numbered file added by hand sits beside it under a different name, pinned to
# the release it was created on, and serves that release's packages into the next
# release's transaction. migrations/1788901901.sh replaces one with the other.
if [[ -d /etc/yum.repos.d ]]; then
  shopt -s nullglob
  numbered=(/etc/yum.repos.d/cuda-fedora[0-9]*.repo)
  shopt -u nullglob
  if ((${#numbered[@]} == 0)); then
    pass "no release-numbered CUDA repository shadows the release-following one"
  else
    fail "no release-numbered CUDA repository shadows the release-following one" \
      "${numbered[*]} — run migrations/1788901901.sh"
  fi
else
  pass "skipped, no /etc/yum.repos.d on this machine"
fi
finish
