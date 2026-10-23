# Hyprland

## Files

| Path | Holds |
|---|---|
| `config/hypr/hyprland.lua` | The entry file: sources everything below, in order |
| `default/hypr/autostart.lua` | What starts with the session |
| `default/hypr/bindings/` | `tiling`, `media`, `utilities`: the keys every machine gets |
| `default/hypr/apps/` | Window rules, one file per application |
| `default/hypr/{envs,input,looknfeel,windows}.lua` | Defaults |
| `config/hypr/*.lua` | The per-machine layer, copied to `~/.config/hypr/` and sourced last |
| `config/hypr/{hypridle,hyprlock,hyprsunset}.conf` | Idle, lock screen, night light |

Files under `default/` are live after `hyprctl reload`. Files under `config/` have to be
deployed first; see [architecture.md](architecture.md).

## Lua, and the hyprlang left beside it

Hyprland reads `hyprland.lua` in place of `hyprland.conf` whenever it exists, deciding
once at startup, and 0.57 reads nothing else. The `.conf` files are kept beside their
Lua twins until 0.57 and **both still change together**; `test/hypr-lua-test.sh` checks
each `.conf` has its `.lua`, and has Hyprland itself verify the Lua config once per theme.

The language reaches past the config. A Lua session takes its runtime commands in Lua
too, and refuses the old ones -- and a hyprlang session refuses the new ones:

| Was | Is |
|---|---|
| `hyprctl dispatch workspace 3` | `hyprctl dispatch 'hl.dsp.focus({ workspace = 3 })'` |
| `hyprctl dispatch focuswindow address:0x1` | `hyprctl dispatch 'hl.dsp.focus({ window = "address:0x1" })'` |
| `hyprctl dispatch movetoworkspacesilent 2,address:0x1` | `hyprctl dispatch 'hl.dsp.window.move({ workspace = 2, window = "address:0x1", follow = false })'` |
| `hyprctl dispatch dpms off` | `hyprctl dispatch 'hl.dsp.dpms({ action = "off" })'` |
| `hyprctl keyword cursor:invisible true` | `hyprctl eval 'hl.config({ cursor = { invisible = true } })'` |
| `hyprctl keyword workspace 1, monitor:DP-1` | `hyprctl eval 'hl.workspace_rule({ workspace = "1", monitor = "DP-1" })'` |

The same goes for the shell's `Hyprland.dispatch()`, which sends its string unchanged,
and for `hyprctl getoption`, which now prints `bool: false` where it printed `int: 0`.
Arguments are checked: an unknown key is an error, not ignored, so an `ok` means it ran.
`/usr/share/hypr/stubs/hl.meta.lua` lists every dispatcher, though not their arguments.
`test/hypr-lua-test.sh` fails on any call left in the old form.

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

The panels are a **submap**, opened by `SUPER + D`, in `default/hypr/bindings/utilities.lua`.
`hl.define_submap` scopes its bindings to the function it is given. The `.conf` twin has
no such scope, and its closing `submap = reset` is not optional there: without it every
binding sourced afterwards lands inside the submap.

Many bindings call the shell and fall back when it does not answer:

    desktop-shell shell toggleLauncher >/dev/null 2>&1 || desktop-menu apps

That is what keeps the keys working while the shell is down.

## Window rules

Ghostty is the only terminal and it cannot set a Wayland app id, so every window it opens
has the class `com.mitchellh.ghostty`. Rules for the TUIs the desktop opens therefore
match on **title**, which each `desktop-launch-*` script passes with `--title`, and on
Ghostty's class as well so an unrelated window with the same title is not caught. See
`default/hypr/apps/system.lua`.

A title match is weaker than a class match. A program that renames its own window escapes
it: yazi and tmux do, bluetui does not. A new TUI has to be checked, with
`hyprctl clients`, not assumed.

## Monitors

`desktop-cmd-monitors-switch` applies a layout and writes `~/.config/hypr/monitors.lua`.

    desktop-cmd-monitors-switch           # the best layout for what is attached
    desktop-cmd-monitors-switch <name>    # a named one
    desktop-cmd-monitors-switch --list    # what could be applied now

Layouts are defined in the script. Connectors are resolved by monitor model when a layout
is applied, because the same screen comes up as a different `DP-n` from one day to the
next. `desktop-monitors-watch` runs it on every plug and unplug.

## Workspaces

`desktop-workspace-pin` decides which screen each workspace sits on and writes
`~/.config/hypr/workspaces.lua`. `desktop-workspace-start` then opens the login windows
and moves each to its workspace once it has mapped. It moves them rather than using
`[workspace N]` exec rules, which follow the spawned process and so miss AppImages that
re-exec and browser web apps that belong to an earlier browser process.
