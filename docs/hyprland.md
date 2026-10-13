# Hyprland

## Files

| Path | Holds |
|---|---|
| `default/hypr/autostart.conf` | What starts with the session |
| `default/hypr/bindings/` | `tiling`, `media`, `utilities`: the keys every machine gets |
| `default/hypr/apps/` | Window rules, one file per application |
| `default/hypr/{envs,input,looknfeel,windows}.conf` | Defaults |
| `config/hypr/*.conf` | The per-machine layer, copied to `~/.config/hypr/` and sourced last |
| `config/hypr/{hypridle,hyprlock,hyprsunset}.conf` | Idle, lock screen, night light |

Files under `default/` are live after `hyprctl reload`. Files under `config/` have to be
deployed first; see [architecture.md](architecture.md).

## Two config languages, for now

Hyprland 0.57 stops reading `hyprland.conf` and reads `hyprland.lua`. Until the switch,
every hyprlang file has a Lua twin beside it and **both must change together**.
`test/hypr-lua-test.sh` holds that: it checks each `.conf` has its `.lua`, and has
Hyprland itself verify the Lua half once per theme.

## Bindings

`bindd` everywhere, because the description is what `SUPER + K` lists
(`desktop-menu-keybindings`) and what a bar tooltip shows (`desktop-shortcuts`).

A few worth knowing:

| Key | Does |
|---|---|
| `SUPER + SPACE` | Launcher |
| `SUPER + ALT + SPACE` | The desktop menu |
| `SUPER + ESCAPE` | Power menu |
| `SUPER + K` | Every binding, searchable |
| `SUPER + D`, then a letter | A panel: `A` audio, `I` AI, `B` Bluetooth, `C` CPU, `F` storage, ... |
| `SUPER + A` | Ask an agent |
| `SUPER + C` | Voice command |
| `SUPER + V` | Clipboard history |
| `SUPER + ALT + M` | The chat named in `~/.config/desktop/chat.conf` |
| `PRINT` | Screenshot of a region; `SHIFT` for a window, `CTRL` for a display |
| `ALT + PRINT` | Screen recording |

The panels are a **submap**, opened by `SUPER + D`. Its closing `submap = reset` in
`default/hypr/bindings/utilities.conf` is not optional: more files are sourced after it,
and without the reset every binding in them lands inside the submap.

Many bindings call the shell and fall back when it does not answer:

    desktop-shell shell toggleLauncher >/dev/null 2>&1 || desktop-menu apps

That is what keeps the keys working while the shell is down.

## Window rules

Ghostty is the only terminal and it cannot set a Wayland app id, so every window it opens
has the class `com.mitchellh.ghostty`. Rules for the TUIs the desktop opens therefore
match on **title**, which each `desktop-launch-*` script passes with `--title`, and on
Ghostty's class as well so an unrelated window with the same title is not caught. See
`default/hypr/apps/system.conf`.

A title match is weaker than a class match. A program that renames its own window escapes
it: yazi and tmux do, bluetui does not. A new TUI has to be checked, with
`hyprctl clients`, not assumed.

## Monitors

`desktop-cmd-monitors-switch` applies a layout and writes `~/.config/hypr/monitors.conf`.

    desktop-cmd-monitors-switch           # the best layout for what is attached
    desktop-cmd-monitors-switch <name>    # a named one
    desktop-cmd-monitors-switch --list    # what could be applied now

Layouts are defined in the script. Connectors are resolved by monitor model when a layout
is applied, because the same screen comes up as a different `DP-n` from one day to the
next. `desktop-monitors-watch` runs it on every plug and unplug.

## Workspaces

`desktop-workspace-pin` decides which screen each workspace sits on and writes
`~/.config/hypr/workspaces.conf`. `desktop-workspace-start` then opens the login windows
and moves each to its workspace once it has mapped. It moves them rather than using
`[workspace N]` exec rules, which follow the spawned process and so miss AppImages that
re-exec and browser web apps that belong to an earlier browser process.
