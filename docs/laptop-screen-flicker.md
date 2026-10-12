# The laptop's screen flickers while the bar moves

## What is wrong

The laptop's own panel (`eDP-1`, driven by the Intel GPU through `i915`) uses PSR2
"selective fetch": only the part of the frame that changed is sent to the screen. A small
region redrawn many times a second -- the orb in the bar while an agent works, the line
along the clock -- makes the whole panel flicker. External monitors are not affected.

Found on 2026-10-12. What pinned it down:

- screenshots of the bar were steady, so the flicker happens after the compositor;
- the kernel log has `Selective fetch area calculation failed in pipe A`;
- `hyprctl keyword debug:damage_tracking 0` (repaint whole frames) made it stop.

The fix is one kernel argument, `i915.enable_psr2_sel_fetch=0`. It is read at boot, so
it has to be stored where the boot loader finds it, and a reboot is needed.

## Steps

### 1. Store the argument

```bash
sudo grubby --update-kernel=ALL --args="i915.enable_psr2_sel_fetch=0"
```

This is what makes it survive. With `--update-kernel=ALL`, grubby writes to:

| Where | What it covers |
|---|---|
| the boot entry of every installed kernel | every reboot from now on |
| `/etc/kernel/cmdline` | every kernel a future update installs |
| `GRUB_CMDLINE_LINUX` in `/etc/default/grub` | a regenerated grub config |

### 2. Check it was stored, before rebooting

```bash
sudo grubby --info=ALL | grep -c enable_psr2_sel_fetch=0     # one per installed kernel
grep -c enable_psr2_sel_fetch=0 /etc/kernel/cmdline /etc/default/grub   # 1 for each file
```

If either file prints `0`, do not reboot yet -- the argument would be lost at the next
kernel update. Run step 1 again and read its output.

### 3. Reboot

```bash
systemctl reboot
```

### 4. Check it is in effect

```bash
cat /proc/cmdline
```

`i915.enable_psr2_sel_fetch=0` must be in the output. Then look at the laptop's bar while
an agent is working and the orb moves: it should be steady.

### 5. After the next kernel update

Run step 4 once more after the first boot into a new kernel. That is the real proof that
it survives.

## If it still flickers

Turn panel self-refresh off altogether, then reboot:

```bash
sudo grubby --update-kernel=ALL --args="i915.enable_psr=0"
```

## Undo

```bash
sudo grubby --update-kernel=ALL --remove-args="i915.enable_psr2_sel_fetch=0"
```

Then reboot.

## A stopgap that does not survive

```bash
hyprctl keyword debug:damage_tracking 0
```

Stops the flicker at once, without a reboot, by repainting whole frames on every monitor.
It costs power and is gone at the next `hyprctl reload` or login. Use it to confirm the
diagnosis, not as the fix.

## Where the repo does this

- `install/config/hardware/intel-psr.sh` runs step 1 on a clean install, and only on a
  machine whose built-in panel is driven by `i915`.
- `migrations/1791787263.sh` runs it once on a machine that already exists, at the next
  `desktop-update`.

Doing step 1 by hand first is harmless: both apply the same argument again and change
nothing.
