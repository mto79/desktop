#!/usr/bin/env bash
# desktop-reboot-check against a fake machine: kernels, an initramfs, NVIDIA, fstab.
#
# The verdicts that decide whether desktop-update offers a reboot with Enter or with an
# explicit yes. What must never happen is a false OK -- a check that could not run passing
# as one that did -- so the root-only checks are also run without root, and must say SKIP.
source "$(dirname "$0")/lib.sh"

require jq || finish

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
mkdir -p "$sandbox/path" "$sandbox/boot" "$sandbox/dev/by-uuid"
for tool in bash env awk sed grep sort head tail tr stat df uname cat; do ln -s "$(command -v "$tool")" "$sandbox/path/$tool"; done
stub() { cat >"$sandbox/path/$1"; chmod +x "$sandbox/path/$1"; }

NEW=7.2.5-200.fc44.x86_64 OLD=7.2.4-200.fc44.x86_64
stub rpm <<'STUB'
#!/usr/bin/env bash
case "$*" in
*kernel-core*) printf '%s\n' $KERNELS ;;
*nvidia-driver-libs*) echo "$LIBS" ;;
"-q akmod-nvidia") [[ -n ${AKMOD:-} ]] ;;
esac
STUB
stub modinfo <<'STUB'
#!/usr/bin/env bash
# modinfo -k <kernel> -F version nvidia
[[ " $MODULES " == *" $2 "* ]] && echo "$MODULE_VERSION"
STUB
stub sudo <<'STUB'
#!/usr/bin/env bash
[[ -n ${ROOT:-} ]] || exit 1
[[ $1 == -n ]] && shift
case $1 in
true) exit 0 ;;
grubby) echo "/boot/vmlinuz-$DEFAULT" ;;
lsinitrd) printf 'usr/lib/systemd/system-generators/systemd-cryptsetup-generator\n' | grep -v "${NOCRYPT:-^$}" ;;
esac
STUB
stub findmnt <<'STUB'
#!/usr/bin/env bash
echo "/dev/mapper/luks-1[/root]"
STUB
stub lsblk <<'STUB'
#!/usr/bin/env bash
printf 'crypt\npart\ndisk\n'
STUB

head -c $((20 * 1024 * 1024)) /dev/zero >"$sandbox/boot/initramfs-$NEW.img"
touch "$sandbox/dev/by-uuid/present"
cat >"$sandbox/fstab" <<'FSTAB'
UUID=present  /       btrfs  defaults  0 0
192.168.2.153:/docs  /nas  nfs  _netdev,nofail,x-systemd.automount  0 0
FSTAB

reboot_check() {
  env -i PATH="$sandbox/path" DESKTOP_BOOT="$sandbox/boot" DESKTOP_DEVDISK="$sandbox/dev" DESKTOP_FSTAB="$sandbox/fstab" \
    KERNELS="$OLD $NEW" LIBS=615.71.09 MODULES="$OLD $NEW" MODULE_VERSION=615.71.09 DEFAULT=$NEW ROOT=1 "$@" \
    bash "$ROOT/bin/desktop-reboot-check" >"$sandbox/out"
  echo $? >"$sandbox/status"
}
status() { cat "$sandbox/status"; }
says() { grep -q "^$1 .*$2" "$sandbox/out"; }

reboot_check
check "an updated machine that will boot passes" test "$(status)" = 0
check "and every check ran, none skipped" lacks -E '^(SKIP|WARN|BAD)' "$sandbox/out"

reboot_check MODULE_VERSION=610.0
check "an NVIDIA module that does not match the libraries fails the check" test "$(status)" = 1
check "and says which versions" says BAD "is 610.0, the libraries 615.71.09"

reboot_check MODULES="$OLD"
check "no NVIDIA module for the new kernel fails it" says BAD "no NVIDIA module for $NEW"
reboot_check MODULES="$OLD" AKMOD=1
check "unless akmods will build it at boot" test "$(status)" = 0
check "which is a warning about a slow first boot" says WARN "akmods builds it at boot"

reboot_check NOCRYPT=cryptsetup
check "an initramfs that cannot unlock the disk fails it" says BAD "cannot unlock the disk"

reboot_check ROOT=
check "without root, the root checks say they did not run" test "$(grep -c '^SKIP' "$sandbox/out")" = 2
check "and do not pass" lacks -E "^OK +(GRUB will start the newest|the initramfs can unlock)" "$sandbox/out"

rm "$sandbox/boot/initramfs-$NEW.img"
reboot_check
check "a missing initramfs fails it" says BAD "initramfs for $NEW is missing"
head -c $((20 * 1024 * 1024)) /dev/zero >"$sandbox/boot/initramfs-$NEW.img"

echo "UUID=gone  /data  ext4  defaults  0 2" >>"$sandbox/fstab"
reboot_check
check "a required disk that is not there fails it" says BAD "/data needs UUID=gone"
check "while a missing network mount with nofail does not" lacks "/nas" "$sandbox/out"
sed -i 's|/data  ext4  defaults|/data  ext4  defaults,nofail|' "$sandbox/fstab"
reboot_check
check "nofail makes the missing disk acceptable" test "$(status)" = 0

reboot_check DEFAULT=$OLD
check "GRUB starting an older kernel is a warning, not a failure" says WARN "GRUB will start $OLD"

reboot_check KERNELS="$NEW" MODULES="$NEW"
check "one kernel alone leaves nothing to fall back to" says WARN "only one kernel"

finish
