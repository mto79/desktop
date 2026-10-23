# Desktop

A Fedora + Hyprland desktop, built on the patterns of Omadora/Omarchy but deliberately
its own thing: fewer apps, fewer features, and every piece understood. It is a personal
fork on purpose — bring good ideas back from upstream, do not propose adopting it.

## Layout

| Path | What it is |
|---|---|
| `bin/` | `desktop-*` commands. On `PATH` via `$DESKTOP_PATH/bin`, set in `config/uwsm/env`. |
| `config/` | **Copied** to `~/.config/` by `install/config/config.sh`. Edits need deploying. |
| `default/` | Sourced **in place** from the repo. Edits are live after `hyprctl reload`. |
| `shell/` | The Quickshell desktop shell: bar, panels, launcher, notifications, OSD. |
| `install/` | `preflight` → `packaging` → `config` → `login` → `post-install`. |
| `migrations/` | `<epoch>.sh`, run once each by `desktop-migrate` on every `desktop-update`. |
| `themes/` | Per-theme colour files, symlinked into `~/.config/desktop/current/`. |

`config/` versus `default/` is the distinction that catches people: a change under
`config/` does nothing until it is copied to `~/.config/`, and a change under `default/`
is live immediately.

## Invariants worth knowing before you change anything

**Ghostty is the only terminal, and it cannot set a Wayland app id.** Every window it
opens is `com.mitchellh.ghostty`. Floating window rules therefore match on **title**,
which each `desktop-launch-*` script passes with `--title`. See
`default/hypr/apps/system.lua`. A title match is weaker than a class match — an app
that renames its own window escapes it (yazi and tmux do; bluetui does not) — so a new
TUI needs checking, not assuming.

**Some files under `~/.config` are generated, not copied.** `hypr/monitors.lua` comes
from `desktop-cmd-monitors-switch` and `hypr/workspaces.lua` from
`desktop-workspace-pin`. Edit the script, never the output.

**Hyprland runs on `hyprland.lua`, and so does everything that talks to it.** A Lua
session refuses `hyprctl dispatch workspace 3` and every `hyprctl keyword`; it takes
`hyprctl dispatch 'hl.dsp.focus({ workspace = 3 })'` and `hyprctl eval '...'`. That holds
for the shell's `Hyprland.dispatch()` as well. The `.conf` files are kept as twins until
0.57 and still change with their `.lua`. See `docs/hyprland.md`.

**`jq` is a hard dependency** of a dozen `bin/desktop-*` scripts. So is `python3` in
places. Neither is optional.

**Anything installed by hand is a clean-install gap.** If a script calls it, an install
script must install it. This has bitten repeatedly — `jq`, `impala` and the NVIDIA
driver were all missing from `install/` while being load-bearing.

## Working here

Commit messages follow Conventional Commits and explain **why**, not what — the diff
already says what. Look at recent history for the register; it is closer to prose than
to changelog lines.

Every change the desktop's behaviour shows gets a line in `CHANGELOG.md`, under the
current month and in the **same commit** — Added, Changed or Fixed, said in terms of what
the desktop now does rather than which files moved. A pure refactor, a test or a doc
fix does not need one.

Run `./test/all` before finishing. It is plain bash, needs no compositor, and takes a
second; every check in it exists because something once broke. Add a case when you fix a
bug — that is what stops it coming back.

Verify changes in the running system too, not by reasoning about them. The shell, the window
rules and the launchers all have ways to be checked cheaply — see the `shell-dev`,
`visual-verification` and `install-scripts` skills.

Marc's own uncommitted work is often in the tree. Stage precisely; never `git add -A`.

**This repository is public.** `.githooks/pre-commit` runs `desktop-privacy-check` on what
is staged and refuses a commit that adds a token, a real home directory, a MAC or email
address, or anything on the deny list in `~/.config/desktop/privacy-deny`. Do not paste
real command output into a comment or a fixture: use `192.0.2.x`, `00:00:5E:00:53:xx`,
`host.example`, `/home/u`. Do not reach for `--no-verify`; see `docs/privacy.md`.

`docs/` has a page per subject. Update the page when the subject changes.
