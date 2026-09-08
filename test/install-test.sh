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
finish
