#!/usr/bin/env bash
# Choosing which backlight the brightness keys move.
#
# A hybrid laptop exposes two. The panel hangs off the integrated GPU, and the discrete
# one advertises a backlight of its own for an output nothing is plugged into --
# nvidia_0 here, for a disconnected eDP-2. brightnessctl with no -d takes the first it
# finds, which was that one, so the keys moved a number nobody could see while the screen
# stayed exactly as bright.
#
# The device is therefore chosen by whether its connector reports itself connected,
# rather than by name, and that is what this checks -- against a fake /sys, so it holds
# on a machine with different hardware than the one it was written on.
source "$(dirname "$0")/lib.sh"

BRIGHTNESS="$ROOT/bin/desktop-brightness"

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT

# backlight <name> <connector-status|none>
backlight() {
  local name="$1" status="$2"
  mkdir -p "$sandbox/sys/class/backlight/$name"
  if [[ $status == none ]]; then
    # What the discrete GPU's entry looks like: its device is a PCI node, with no
    # connector and so no status at all.
    mkdir -p "$sandbox/sys/devices/pci/$name"
    ln -sfn "$sandbox/sys/devices/pci/$name" "$sandbox/sys/class/backlight/$name/device"
  else
    mkdir -p "$sandbox/sys/devices/drm/$name"
    printf '%s\n' "$status" >"$sandbox/sys/devices/drm/$name/status"
    ln -sfn "$sandbox/sys/devices/drm/$name" "$sandbox/sys/class/backlight/$name/device"
  fi
}

# The chooser, lifted out of the script so the fake tree can be pointed at it.
chooser() {
  sed -n '/^backlight_device() {/,/^}$/p' "$BRIGHTNESS" |
    sed "s#/sys/class/backlight#$sandbox/sys/class/backlight#"
}

pick() { (eval "$(chooser)"; backlight_device); }

# The shape of a hybrid laptop. acpi_video0 is in here deliberately: the glob is
# alphabetical, so without it the right answer would also be the first one tried and this
# check would pass for a chooser that simply took whatever came first.
backlight acpi_video0 none
backlight intel_backlight connected
backlight nvidia_0 none
check "the panel's backlight is chosen, not one of the phantoms" \
  test "$(pick)" = "intel_backlight"

rm -rf "$sandbox/sys"
backlight amdgpu_bl0 connected
check "any connected backlight will do -- the name is not what decides" \
  test "$(pick)" = "amdgpu_bl0"

rm -rf "$sandbox/sys"
backlight nvidia_0 none
backlight card0_edp disconnected
check "a backlight on a disconnected output is not chosen" \
  test -z "$(pick 2>/dev/null | grep -x 'card0_edp' || true)"

# A desktop, or a kernel that lays this out differently: fall through to brightnessctl's
# own answer rather than refusing to work at all.
rm -rf "$sandbox/sys"
mkdir -p "$sandbox/bin"
printf '#!/usr/bin/env bash\necho "fallback_device,backlight,1,1%%,1"\n' >"$sandbox/bin/brightnessctl"
chmod +x "$sandbox/bin/brightnessctl"
check "with nothing to go on, brightnessctl's own choice is used" \
  test "$(PATH="$sandbox/bin:$PATH" pick)" = "fallback_device"

check "an unknown argument is refused" \
  lacks . <<<"$(bash "$BRIGHTNESS" wibble 2>/dev/null || true)"

finish
