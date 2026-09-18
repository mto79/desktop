#!/usr/bin/env bash
# desktop-storage-details, with df and lsblk faked as this laptop: one encrypted btrfs
# volume mounted twice, two boot partitions, a KeePassXC AppImage mounted as FUSE, an
# empty card-reader slot, and a USB stick.
#
# The ways it can mislead: counting the btrfs volume twice; listing an AppImage as a
# drive; missing that the system disk is encrypted, since the LUKS layer sits between it
# and the disk; and measuring ~/Downloads as 28 bytes because it is a symlink.
source "$(dirname "$0")/lib.sh"

require jq du flock || finish

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
mkdir -p "$sandbox/path" "$sandbox/runtime" "$sandbox/home/.local/share/Trash" "$sandbox/data/Downloads"
for tool in bash env jq awk sed cat find grep sort head tee mv flock timeout du nice ionice wc; do
  ln -s "$(command -v "$tool")" "$sandbox/path/$tool"
done
stub() { cat >"$sandbox/path/$1"; chmod +x "$sandbox/path/$1"; }

stub df <<'STUB'
#!/usr/bin/env bash
cat <<'OUT'
Filesystem         Type                     1B-blocks         Used         Avail Mounted on
/dev/dm-0          btrfs                2045613441024 573139886080 1471321333760 /
/dev/dm-0          btrfs                2045613441024 573139886080 1471321333760 /home
/dev/nvme0n1p2     ext4                    2040373248    894255104    1021968384 /boot
KeePassXC.AppImage fuse.KeePassXC.AppImage   49938432     49938432             0 /tmp/.mount_KeePas
/dev/sdc1          vfat                   31000000000   1000000000   30000000000 /run/media/mto/STICK
OUT
STUB
stub lsblk <<'STUB'
#!/usr/bin/env bash
case "${@: -1}" in
/dev/dm-0) echo '{"blockdevices":[{"name":"luks-1","type":"crypt","rm":false,"hotplug":false,"path":"/dev/dm-0","children":[{"name":"nvme0n1p3","type":"part","rm":false,"hotplug":false,"children":[{"name":"nvme0n1","type":"disk","rm":false,"hotplug":false,"tran":"nvme","model":"KIOXIA 2048GB","path":"/dev/nvme0n1"}]}]}]}' ;;
/dev/nvme0n1p2) echo '{"blockdevices":[{"name":"nvme0n1p2","type":"part","rm":false,"hotplug":false,"children":[{"name":"nvme0n1","type":"disk","rm":false,"hotplug":false,"tran":"nvme","model":"KIOXIA 2048GB","path":"/dev/nvme0n1"}]}]}' ;;
/dev/sdc1) echo '{"blockdevices":[{"name":"sdc1","type":"part","rm":true,"hotplug":true,"children":[{"name":"sdc","type":"disk","rm":true,"hotplug":true,"tran":"usb","model":"Cruzer","path":"/dev/sdc"}]}]}' ;;
esac
STUB
stub xdg-user-dir <<STUB
#!/usr/bin/env bash
echo "$sandbox/home/Downloads"
STUB

details() {
  env -i PATH="$sandbox/path" HOME="$sandbox/home" XDG_RUNTIME_DIR="$sandbox/runtime" \
    bash "$ROOT/bin/desktop-storage-details" "$@"
}

out=$(details)
fs() { jq -c --arg m "$1" ".filesystems[] | select(.mount == \$m) | $2" <<<"$out"; }

check "a volume mounted twice is one filesystem, with both mount points" test "$(fs / .mounts)" = '["/","/home"]'
check "and is listed once" test "$(jq '[.filesystems[] | select(.device == "/dev/dm-0")] | length' <<<"$out")" = 1
check "an AppImage is not a drive" test "$(jq '[.filesystems[] | select(.fstype | startswith("fuse"))] | length' <<<"$out")" = 0
check "encryption is seen through the LUKS layer" test "$(fs / '[.encrypted, .model]')" = '[true,"KIOXIA 2048GB"]'
check "a boot partition on the same disk is not encrypted" test "$(fs /boot .encrypted)" = false
check "a USB stick is removable, with its disk to power off" test "$(fs /run/media/mto/STICK '[.removable, .disk]')" = '[true,"/dev/sdc"]'
check "the system volume comes first, removable drives last" \
  test "$(jq -c '[.filesystems[].mount]' <<<"$out")" = '["/","/boot","/run/media/mto/STICK"]'

# ~/Downloads as a symlink into a data folder, holding a megabyte.
head -c 1000000 /dev/zero >"$sandbox/data/Downloads/file"
ln -s "$sandbox/data/Downloads" "$sandbox/home/Downloads"
head -c 2000 /dev/zero >"$sandbox/home/.local/share/Trash/old"

usage=$(details --usage)
check "a symlinked Downloads is measured where it points, not as a link" \
  test "$(jq -r 'select(.id == "downloads") | .bytes >= 1000000' <<<"$usage")" = true
# Only the home folders are sandboxed; a system Flatpak in /var/lib may be measured too.
check "folders that do not exist are left out" test "$(jq -r .id <<<"$usage" | grep -cE '^(cache|containers)$')" = 0

check "a second ask within the hour reads the answer kept" test "$(details --usage)" = "$usage"

rm -f "$sandbox/runtime/desktop-storage-usage.jsonl" "$sandbox/home/Downloads"
stub xdg-user-dir <<STUB
#!/usr/bin/env bash
echo "$sandbox/home"
STUB
check "home is never measured as Downloads when none is configured" \
  test "$(details --usage | jq -r 'select(.id == "downloads") | .path')" = ""

finish
