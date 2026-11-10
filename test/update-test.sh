#!/usr/bin/env bash
# desktop-update runs a dozen updaters in a row. A kubectl download that broke halfway used to
# end the whole run there -- set -e -- and with it that day's system packages and firmware.
# What is checked: a step that fails is said and the rest still run, the update still ends in
# an error, and the two steps everything else depends on -- the repo and its migrations --
# still stop it when they fail.
#
# Every step is a stub that writes its name down, and fails when told to.
source "$(dirname "$0")/lib.sh"

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
mkdir -p "$sandbox/path"

steps=$(grep -oE '^desktop-[a-z-]+( [a-z]+)?$' "$ROOT/bin/desktop-update" | cut -d' ' -f1 | sort -u)
for step in $steps desktop-shell notify-send sudo; do
  cat >"$sandbox/path/$step" <<STUB
#!/usr/bin/env bash
echo "$step \$*" >>"$sandbox/ran"
[[ -e "$sandbox/fail-$step" ]] && exit 1
[[ -e "$sandbox/interrupt-$step" ]] && exit 130
exit 0
STUB
  chmod +x "$sandbox/path/$step"
done

# Output to a file rather than captured: the sudo keep-alive loop runs on in the background
# for up to a minute, holding any pipe it was given open.
update() {
  rm -f "$sandbox/ran"
  PATH="$sandbox/path:/usr/bin:/bin" XDG_RUNTIME_DIR="$sandbox" \
    bash "$ROOT/bin/desktop-update" >"$sandbox/out" 2>&1
}
ran() { grep -q "^$1" "$sandbox/ran"; }

update && status=0 || status=$?
check "with nothing failing, the update succeeds" test "$status" = 0
check "and runs every step" ran desktop-update-firmware
check "and says nothing failed" lacks 'Not updated' "$sandbox/out"

touch "$sandbox/fail-desktop-update-kubectl"
update && status=0 || status=$?
check "a step that fails does not stop the ones after it" ran desktop-update-hashicorp
check "system packages included" ran desktop-update-system-pkgs
check "and firmware" ran desktop-update-firmware
check "nor the reboot question" ran desktop-update-restart
check "it is named at the end" grep -q 'Not updated: desktop-update-kubectl' "$sandbox/out"
check "and on the desktop" grep -q 'notify-send .*Some updates failed desktop-update-kubectl' "$sandbox/ran"
check "before the reboot question, not after it" \
  test "$(grep -n 'Some updates failed' "$sandbox/ran" | cut -d: -f1)" -lt \
  "$(grep -n '^desktop-update-restart' "$sandbox/ran" | cut -d: -f1)"
check "and the update still ends in an error" test "$status" != 0

touch "$sandbox/fail-desktop-update-hashicorp"
update
check "two that fail are both named, with what they were run with" \
  grep -q 'Not updated: desktop-update-kubectl desktop-update-hashicorp packer desktop-update-hashicorp vault' "$sandbox/out"
rm "$sandbox"/fail-*

touch "$sandbox/interrupt-desktop-update-oc"
update && status=0 || status=$?
check "Ctrl-C in one step stops the whole update" lacks 'desktop-update-kubectl' "$sandbox/ran"
check "with Ctrl-C's status" test "$status" = 130
rm "$sandbox"/interrupt-*

touch "$sandbox/fail-desktop-update-git"
update && status=0 || status=$?
check "the repo failing to update still stops it" lacks 'desktop-migrate' "$sandbox/ran"
check "with an error" test "$status" != 0
rm "$sandbox"/fail-*

touch "$sandbox/fail-desktop-migrate"
update
check "and so do its migrations" lacks 'desktop-update-cargo' "$sandbox/ran"

finish
