# Architecture

The repository is cloned to `~/.local/share/desktop` and stays there. Part of it is copied
out at install time, part of it is read in place for as long as the machine runs.

## The two kinds of configuration

| | `config/` | `default/` |
|---|---|---|
| Where it is read from | `~/.config/`, after being **copied** there | The repository itself |
| An edit takes effect | Once deployed | After `hyprctl reload` |
| Whose it is | Yours to change per machine | The desktop's defaults |
| Deployed by | `install/config/config.sh`, or `desktop-refresh-config <path>` for one file | Nothing; it is sourced |

`~/.config/hypr/hyprland.conf` shows how they combine: it sources every file under
`default/hypr/` first, then the active theme, then the files in `~/.config/hypr/`, so a
personal setting overrides a default without editing it.

`desktop-refresh-config hypr/hyprlock.conf` copies one file from `config/` over the
deployed one, keeping a timestamped backup of what was there.

Two files under `~/.config/hypr/` are neither: `monitors.conf` is written by
`desktop-cmd-monitors-switch` and `workspaces.conf` by `desktop-workspace-pin`. Change the
script, not the output.

## Commands

Everything the desktop does is a `desktop-*` script in `bin/`, on `PATH` through
`DESKTOP_PATH` in `config/uwsm/env`. The prefix says what kind it is:

| Prefix | Does |
|---|---|
| `desktop-launch-*` | Opens a program, usually in Ghostty with a `--title` the window rules match |
| `desktop-cmd-*` | An action bound to a key: screenshot, screen recording, monitor layout |
| `desktop-menu*` | The menus, and the select/input prompts they are built from |
| `desktop-status-*` | JSON for one bar widget |
| `desktop-*-details` | JSON for one panel |
| `desktop-toggle-*` | Flips one switch |
| `desktop-refresh-*` | Redeploys one program's config from `config/` |
| `desktop-restart-*` | Restarts one program |
| `desktop-update*` | The update, one script per source |
| `desktop-theme-*` | Lists, sets, installs and removes themes |
| `desktop-agent-*` | Coding agents: running them, tracking them, laying out their windows |

Most are bash. A few are Python where the work is parsing: `desktop-agent-tokens`,
`desktop-tmux-sidebar`, `desktop-dash-news`, `desktop-voice-endpoint`,
`desktop-privacy-check`. `jq` and `python3` are hard dependencies.

## What starts at login

`default/hypr/autostart.conf`, through `uwsm`:

- `hypridle`, which locks and suspends on idle
- `desktop-launch-shell`, the Quickshell shell (see [shell.md](shell.md))
- `fcitx5` for input methods
- `swaybg` with the active theme's background
- `hyprpolkitagent` for authentication prompts
- `desktop-monitors-watch`, which re-applies a monitor layout on every plug and unplug
- `desktop-clipboard watch`, the clipboard history

`desktop-workspace-start` then opens the day's windows, each on its own workspace.

## Where state lives

| Path | What |
|---|---|
| `~/.config/desktop/` | Per-machine settings the scripts read: `shell.json`, `hooks/`, `worktrees/`, `say.dict`, and the ones the repository must not carry: `backup.conf`, `chat.conf`, `privacy-deny` (see [privacy.md](privacy.md)) |
| `~/.config/desktop/current/` | Symlinks to the active theme and background |
| `~/.local/state/desktop/` | What should survive a reboot: which migrations ran, when the last backup succeeded, dashboard data |
| `$XDG_RUNTIME_DIR/desktop/` | What should not: one JSON file per running agent session, capture pid files |
| `~/.cache/desktop/` | What can be recomputed: token counts per day |

## Hooks

`desktop-hook <name>` runs `~/.config/desktop/hooks/<name>` when it exists. Samples for
`post-update`, `theme-set` and `font-set` are in `config/desktop/hooks/`. These are the
desktop's own extension points and are unrelated to the git hook in `.githooks/`, which
[privacy.md](privacy.md) covers.
