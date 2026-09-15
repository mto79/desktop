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

# `qt6-qtsvg ` sat in the list with a trailing space. dnf happens to trim it, so it did
# no harm -- but the list is also read by greps and by `grep -qxF`, which do not, and a
# name that looks present while failing an exact match is a bad way to lose a package.
padded=$(grep -nE '^[[:space:]]+|[[:space:]]+$' "$packages" | grep -v '^[0-9]*:#' || true)
if [[ -z $padded ]]; then
  pass "no package name is padded with whitespace"
else
  fail "no package name is padded with whitespace" "$padded"
fi

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

# Dictation is English and Dutch. Whisper's .en models are English-only -- they cannot
# transcribe another language and cannot detect one at all -- so a clean install that
# fetches base.en silently loses half of what this desktop is used for. The model is
# named in one place; this is that place being watched.
vox="$ROOT/install/packaging/voxtype.sh"
model=$(grep -oP 'setup --download --model \K\S+' "$vox" 2>/dev/null || true)
if [[ -n $model && $model != *.en ]]; then
  pass "a clean install gets a multilingual dictation model ($model)"
else
  fail "a clean install gets a multilingual dictation model" "voxtype.sh downloads '${model:-nothing}'"
fi
if grep -qF "set_voxtype whisper language '[\"en\", \"nl\"]'" "$vox"; then
  pass "the dictation languages are set at install time"
else
  fail "the dictation languages are set at install time" "voxtype.sh does not set language"
fi

# The voxtype settings are merged into a config voxtype itself owns, and the keys they
# set -- enabled, mode, key -- each appear in several sections of that file. A sed
# rewrote whichever section came first: the hotkey mode landed on [output], and the
# audio-feedback beeps were switched on by accident. The merger has to respect sections,
# and has to be safe to run twice, because every desktop-update runs it again.
if require python3; then
  vox_sandbox=$(mktemp -d)
  cat >"$vox_sandbox/config.toml" <<'FIXTURE'
[hotkey]
key = "SCROLLLOCK"
# mode = "push_to_talk"
# enabled = true

[audio]
max_duration_secs = 60

[audio.feedback]
# enabled = true

[whisper]
language = "en"

[output]
mode = "type"
FIXTURE

  (
    VOXTYPE_CONFIG="$vox_sandbox/config.toml"
    eval "$(sed -n '/^set_voxtype() {/,/^}$/p' "$ROOT/install/packaging/voxtype.sh")"
    for _ in 1 2; do
      set_voxtype whisper language '["en", "nl"]'
      set_voxtype hotkey key '"RIGHTALT"'
      set_voxtype hotkey mode '"push_to_talk"'
      set_voxtype hotkey enabled true
      set_voxtype audio max_duration_secs 20
    done
  )

  merged=$(python3 -c '
import tomllib, sys
d = tomllib.load(open(sys.argv[1], "rb"))
print(d["hotkey"]["key"], d["hotkey"]["mode"], d["hotkey"]["enabled"],
      d["output"]["mode"], d["audio"]["max_duration_secs"],
      d["whisper"]["language"], "vad" in d,
      d.get("audio", {}).get("feedback", {}).get("enabled"))' "$vox_sandbox/config.toml" 2>/dev/null)

  # The second-to-last field is whether a [vad] section was created -- it must not be,
  # see the note in voxtype.sh. The last is audio.feedback.enabled: None means the beeps
  # were left alone, which is what a section-blind sed got wrong.
  if [[ $merged == "RIGHTALT push_to_talk True type 20 ['en', 'nl'] False None" ]]; then
    pass "the voxtype settings merge into the right sections, twice over"
  else
    fail "the voxtype settings merge into the right sections, twice over" "$merged"
  fi
  rm -rf "$vox_sandbox"
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

# The upgrade-shaped failure, which the checks above do not catch: NVIDIA signs each
# release's packages with that release's key, and `dnf system-upgrade` verifies fc(N+1)
# packages while the machine still runs N. A gpgkey naming only the current release
# passes every static check, then fails the offline transaction after the whole
# multi-gigabyte download. So the next release's key has to be trusted in advance --
# but only once NVIDIA has published it, which is why this asks the network.
cuda_repo=/etc/yum.repos.d/cuda-fedora-nvidia.repo
if [[ -f $cuda_repo ]] && have curl && have rpm; then
  next=$(($(rpm -E %fedora) + 1))
  next_base="https://developer.download.nvidia.com/compute/cuda/repos/fedora${next}/x86_64"
  if curl -fsSL --max-time 10 -o /dev/null "$next_base/repodata/repomd.xml" 2>/dev/null; then
    if grep -q "^gpgkey=.*fedora${next}/" "$cuda_repo"; then
      pass "the CUDA repo trusts Fedora ${next}'s signing key"
    else
      fail "the CUDA repo trusts Fedora ${next}'s signing key" \
        "NVIDIA publishes fedora${next} but the repo trusts only older keys — a system-upgrade would fail verification after downloading everything"
    fi
  else
    pass "skipped, NVIDIA has published no fedora${next} repository yet"
  fi
else
  pass "skipped, no CUDA repo or no curl on this machine"
fi
finish
