#!/usr/bin/env bash
# What the update icon says, and the one notification it sends.
#
# Each case is something that went wrong: the git check printed its own error to stdout,
# which lit the icon permanently in a repository with no tags; dnf asked whether to import
# a signing key and waited forever on a stdin nobody would write to; three bars, one per
# monitor, ran three checks at once and would have sent three notifications.
source "$(dirname "$0")/lib.sh"

require git jq flock timeout || finish

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT

# A PATH holding only what is named here, so a real dnf or flatpak on this machine can
# neither answer for the stubs nor be run by the test.
mkdir -p "$sandbox/path" "$sandbox/runtime" "$sandbox/state"
for tool in bash env git jq awk grep find flock timeout mv cat mkdir dirname sleep tr sed date; do
  ln -s "$(command -v "$tool")" "$sandbox/path/$tool"
done
ln -s "$ROOT/bin/desktop-cmd-present" "$sandbox/path/"

# dnf as it is when a repository key is not imported yet: it asks first, and only answers
# once the question has been answered -- or read end-of-file, which it takes as no.
cat >"$sandbox/path/dnf" <<'STUB'
#!/usr/bin/env bash
case $2 in
makecache) printf 'Is this ok [y/N]: ' >&2; read -r _ ;;
check-upgrade)
  [[ -e $SANDBOX/no-packages ]] && exit 0
  printf '\nkernel.x86_64  6.20.1-200.fc44  updates\nmesa.x86_64  26.1-1.fc44  updates\n\nObsoleting packages\nold.x86_64  1-1  updates\n'
  exit 100 ;;
esac
STUB
cat >"$sandbox/path/notify-send" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$SANDBOX/notified"
STUB
chmod +x "$sandbox/path/dnf" "$sandbox/path/notify-send"

# This desktop's repository, one commit behind its upstream.
git init -q --bare "$sandbox/origin.git"
git clone -q "$sandbox/origin.git" "$sandbox/desktop" 2>/dev/null
git -C "$sandbox/desktop" -c user.name=t -c user.email=t@t commit -q --allow-empty -m one
git -C "$sandbox/desktop" push -q origin HEAD 2>/dev/null
git -C "$sandbox/desktop" branch -q -u "origin/$(git -C "$sandbox/desktop" branch --show-current)"

check_updates() {
  rm -f "$sandbox/runtime/desktop-update-available.json"
  env -i PATH="$sandbox/path" HOME="$sandbox" SANDBOX="$sandbox" DESKTOP_PATH="$sandbox/desktop" \
    XDG_RUNTIME_DIR="$sandbox/runtime" XDG_STATE_HOME="$sandbox/state" \
    timeout 10 bash "$ROOT/bin/desktop-update-available" "$@"
}
notifications() { [[ -e $sandbox/notified ]] && grep -c . "$sandbox/notified" || echo 0; }

# A stdin held open and never written to, as the bar gives it.
out=$(sleep 30 | check_updates --json)
check "a check under the bar does not wait on dnf's question" test -n "$out"
check "packages are counted, and the obsoleting section is not" \
  test "$(jq -c '.sources | map({id, count, label})' <<<"$out")" = '[{"id":"dnf","count":2,"label":"Fedora packages"}]'
check "and named, without their architecture" test "$(jq -c '.sources[0].items' <<<"$out")" = '["kernel","mesa"]'
check "the check says when it ran" test "$(jq '.checked > 1700000000' <<<"$out")" = true
check "being level with upstream is not an update, and prints nothing else" \
  test "$(check_updates)" = "2 Fedora packages"

check_updates --json --notify >/dev/null
check "updates are announced" test "$(notifications)" = 1
check "with what they are" grep -q "2 Fedora packages" "$sandbox/notified"
check_updates --json --notify >/dev/null
check "and not again on the next check" test "$(notifications)" = 1

# Someone pushes to the desktop repository: a new kind of update is news.
git clone -q "$sandbox/origin.git" "$sandbox/other" 2>/dev/null
git -C "$sandbox/other" -c user.name=t -c user.email=t@t commit -q --allow-empty -m two
git -C "$sandbox/other" push -q 2>/dev/null
out=$(check_updates --json --notify)
check "commits upstream are counted" grep -q '{"id":"desktop","count":1,' <<<"$out"
check "and listed by subject" test "$(jq -c '.sources[] | select(.id == "desktop") | .items' <<<"$out")" = '["two"]'

# A check a minute old is reused, unless the panel asks for a fresh one.
env -i PATH="$sandbox/path" HOME="$sandbox" SANDBOX="$sandbox" DESKTOP_PATH="$sandbox/desktop" \
  XDG_RUNTIME_DIR="$sandbox/runtime" XDG_STATE_HOME="$sandbox/state" \
  bash "$ROOT/bin/desktop-update-available" --json >/dev/null
touch "$sandbox/no-packages"
reused=$(env -i PATH="$sandbox/path" HOME="$sandbox" SANDBOX="$sandbox" DESKTOP_PATH="$sandbox/desktop" \
  XDG_RUNTIME_DIR="$sandbox/runtime" XDG_STATE_HOME="$sandbox/state" \
  bash "$ROOT/bin/desktop-update-available" --json)
fresh=$(env -i PATH="$sandbox/path" HOME="$sandbox" SANDBOX="$sandbox" DESKTOP_PATH="$sandbox/desktop" \
  XDG_RUNTIME_DIR="$sandbox/runtime" XDG_STATE_HOME="$sandbox/state" \
  bash "$ROOT/bin/desktop-update-available" --json --fresh)
rm "$sandbox/no-packages"
check "a check a minute old is reused" grep -q '"id":"dnf"' <<<"$reused"
check "and --fresh checks again" lacks '"id":"dnf"' <<<"$fresh"
check "and a new source is announced" test "$(notifications)" = 2

# desktop-update ran: nothing left, so the next updates are news again.
git -C "$sandbox/desktop" pull -q 2>/dev/null
touch "$sandbox/no-packages"
check "with nothing to update the plain form prints nothing" test -z "$(check_updates --notify)"
rm "$sandbox/no-packages"
check_updates --json --notify >/dev/null
check "updates after a clean slate are announced again" test "$(notifications)" = 3

# Three bars asking at once get one check and one notification between them.
rm -f "$sandbox/runtime/desktop-update-available.json" "$sandbox/state/desktop/updates-notified"
for i in 1 2 3; do
  env -i PATH="$sandbox/path" HOME="$sandbox" SANDBOX="$sandbox" DESKTOP_PATH="$sandbox/desktop" \
    XDG_RUNTIME_DIR="$sandbox/runtime" XDG_STATE_HOME="$sandbox/state" \
    timeout 10 bash "$ROOT/bin/desktop-update-available" --json --notify >"$sandbox/bar$i" &
done
wait
check "three bars checking at once send one notification" test "$(notifications)" = 4
check "and all get the same answer" test "$(cat "$sandbox"/bar* | sort -u | grep -c .)" = 1

finish
