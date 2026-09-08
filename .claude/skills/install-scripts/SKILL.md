---
name: install-scripts
description: Changing anything under install/ or migrations/ - packages, repos, packaging scripts, one-time fixes. Read before adding a dependency or assuming a clean install reproduces this machine.
---

# Install scripts and migrations

`install.sh` runs five stages in order: `preflight` → `packaging` → `config` → `login` →
`post-install`. Each has an `all.sh` that sources the rest.

The governing rule: **a clean install must reproduce this machine.** Anything installed
by hand is a bug, not a shortcut. `jq`, `impala` and the whole NVIDIA driver were each
load-bearing while absent from `install/`.

## Packages

`install/desktop-base.packages` is passed to a **single** `dnf install`, so one
unavailable name fails the entire transaction and nothing gets installed. Before adding
a name, check it resolves:

```bash
dnf --disablerepo=pgAdmin4 list --available <name>
```

`--disablerepo=pgAdmin4` because that repo currently fails GPG verification and will
interrupt an otherwise fine transaction.

For anything not in Fedora, add a `install/packaging/<name>.sh` **and source it from
`install/packaging/all.sh`** — a script that nothing sources never runs. Four such
orphans exist today (`openshiftlocal`, `openvpn`, `stack`, `zoom`).

Cargo binaries go in `install/packaging/cargo.sh` and are installed `--locked`, so each
crate builds against the lockfile its author published. Without it cargo re-resolves to
the newest semver-compatible versions, which is how eza broke: palette 0.7.5's library
compiled against palette_derive 0.7.7's macro.

## Repositories

COPRs are enabled in `install/preflight/copr.sh`. Two things to know:

- `solopasha/hyprland` builds for **rawhide only** since Nov 2025. Every `hypr*` package
  installed from it is frozen, and the stack needs a new source before the next Fedora
  release. `hermitfeather/hyprland-dev` is the replacement, currently pinned with
  `includepkgs` so it cannot upgrade the compositor by accident.
- Repos with the release in the URL (`cuda-fedora43`, Signal's `Fedora_43`) must be
  edited by hand on a Fedora upgrade. Prefer `$releasever` where upstream publishes for
  the current release.

## Config that cannot simply be copied

`install/config/config.sh` copies `config/*` into `~/.config/`. That is wrong for files
carrying machine state alongside configuration — Claude Code's `settings.json` holds
auth and auto-mode environment, so its Notification hook is **merged in with `jq`**, and
only when absent. Copy the pattern for anything similar rather than clobbering.

## Migrations

`migrations/<epoch>.sh`, one file per change, run once each by `desktop-migrate` from
`desktop-update`. Name them with `date +%s`.

Use one whenever a change leaves existing machines inconsistent — not for anything a
fresh install already gets right. The existing example rewrites `.desktop` entries that
still launch through alacritty, which would break the moment it is uninstalled.

Make them idempotent and safe to re-run: they are marked done on success, but a skipped
or failed one can be retried.

## Testing install changes without installing

Most of these scripts want sudo and change the system. Verify the parts you can:

- `bash -n` every script you touch.
- Check a repo URL actually answers before writing it into a `.repo` file.
- Test text manipulation (a `sed` into `/etc/default/grub`) against a **copy**, twice,
  to prove it is idempotent.
- Guard hardware-specific scripts so they no-op cleanly elsewhere — `nvidia.sh` returns
  early when no NVIDIA GPU is present, because `packaging/all.sh` sources it everywhere.
