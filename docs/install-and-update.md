# Install and update

The rule that governs all of it: **a clean install must reproduce this machine.** Anything
installed by hand is a gap that shows up on the next install, and `jq`, `impala` and the
NVIDIA driver have each been one.

## Install

`install.sh` sources five stages in order. Each stage has an `all.sh` that sources its
scripts, and a script that no `all.sh` names never runs.

| Stage | Does |
|---|---|
| `preflight` | Guards against an unsuitable system, enables COPRs, configures dnf, keeps sudo alive, marks existing migrations as done |
| `packaging` | One `dnf install` of `desktop-base.packages`, then a script per thing Fedora does not ship |
| `config` | Copies `config/` to `~/.config/`, sets the theme and branding, hardware fixes, git hooks |
| `login` | SDDM, Plymouth, the default keyring, systemd units |
| `post-install` | Clean-up, `updatedb`, reboot |

`desktop-base.packages` goes to a **single** `dnf install`, so one name that does not
resolve fails the whole transaction. Check a name before adding it:

    dnf --disablerepo=pgAdmin4 list --available <name>

Config that carries machine state cannot be copied over. Claude Code's `settings.json`
holds authentication next to its configuration, so `desktop-agent-hooks` merges the hooks
into it instead and leaves the rest alone.

## Update

`desktop-update` runs, in order:

1. `desktop-update-git` pulls the repository
2. `desktop-migrate` runs migrations that have not run here
3. `desktop-update-cargo`, `-oc`, `-flatpak`, `-system-pkgs`, `-firmware`
4. `desktop-update-restart` checks whether the machine would come back up, and offers a
   reboot when one is needed

`desktop-update-available` says what an update would bring without running one; the bar's
update widget reads it.

## Migrations

A migration is `migrations/<epoch>.sh`, run once per machine by `desktop-migrate`. A marker
file under `~/.local/state/desktop/migrations/` records that it ran. A failed one stops the
update and asks whether to skip it.

Write one when a change leaves existing machines inconsistent with a fresh install: a new
file under `config/` that the installer would copy but an existing machine never gets, a
package that was added, a git setting. Do not write one for something a fresh install
already gets right.

    desktop-dev-add-migration      # creates the file, named for the last commit's time

Make it idempotent. It is marked done on success, but a skipped or failed one can be run
again.

## Checking install changes without installing

Most of these scripts want sudo and change the system, so verify the parts that can be:

- `bash -n` every script touched
- `./test/all`: `install-test.sh` checks that every command `bin/` calls is in the package
  list, that no packaging script is left unsourced, and that each `all.sh` names only
  files that exist
- Run text edits against a copy, twice, to prove they are idempotent
- Guard hardware-specific scripts so they do nothing elsewhere, the way `nvidia.sh` returns
  early without an NVIDIA card

`.claude/skills/install-scripts/SKILL.md` has the longer version, including the state of
the COPRs.
