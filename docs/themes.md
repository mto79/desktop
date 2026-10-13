# Themes

A theme is a directory of colour files, one per program, under `themes/<name>/`. Three
ship: `catppuccin`, `nord`, `tokyo-night`.

## What a theme holds

| File | For |
|---|---|
| `shell.json` | The Quickshell shell |
| `hyprland.conf`, `hyprland.lua` | Border and group colours |
| `hyprlock.conf` | The lock screen |
| `ghostty.conf`, `kitty.conf` | Terminals |
| `tmux.conf` | The tmux status line |
| `neovim.lua`, `vscode.json` | Editors |
| `btop.theme`, `gdu.yaml`, `eza.yml` | TUIs |
| `waybar.css`, `mako.ini`, `swayosd.css`, `walker.css` | The fallback bar, notifications, OSD, launcher |
| `chromium.theme`, `icons.theme` | Browser and icon theme |
| `backgrounds/` | Wallpapers |
| `light.mode` | Present only in a light theme |

## How the active theme is found

`~/.config/desktop/current/theme` is a symlink to the active theme, and
`~/.config/desktop/current/background` to the active wallpaper. Every program's config
includes its file through that path, so nothing has to be rewritten to switch.

## Switching

    desktop-theme-list
    desktop-theme-set <name>
    desktop-theme-next
    desktop-theme-bg-next          # SUPER + CTRL + SPACE
    desktop-theme-install <git-url>
    desktop-theme-remove <name>

`desktop-theme-set` moves the symlink, then tells each running program:

- GNOME's colour scheme and icon theme, through `gsettings`
- `btop` re-reads on `SIGUSR2`
- tmux re-sources its config
- the shell reloads in place (`desktop-shell shell reloadTheme`), restarting only if it
  does not answer
- `hyprctl reload`
- the next background

A program with no include mechanism gets a wrapper: `desktop-gdu` builds gdu's config from
the theme each time it runs.

## Adding a theme

Copy an existing directory and change the colours. Both `hyprland.conf` and `hyprland.lua` are needed:
`test/hypr-lua-test.sh` verifies the Lua config once per theme.
