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
| `btop.theme`, `gdu.yaml`, `eza.yml`, `k9s.yaml` | TUIs |
| `waybar.css`, `mako.ini`, `swayosd.css`, `walker.css` | The fallback bar, notifications, OSD, launcher |
| `chromium.theme`, `icons.theme` | Browser and icon theme |
| `backgrounds/` | Wallpapers |
| `light.mode` | Present only in a light theme |

### The shell's colours

`shell.json` names nine colours at the top -- `background`, `foreground`, `muted`, `accent`,
`urgent`, `good`, `caution`, `warning` -- and can override any of them for the bar, panels
and tooltips under `bar`, `popup` and `tooltip`. The bar also takes its surfaces, from the
bar up:

| Key under `bar` | Is |
|---|---|
| `pill` | A pill on the bar: a group, the clock, a workspace |
| `raised` | Above a pill: a hover, a group opened |
| `outline` | The line round a pill |
| `opacity` | How much of the bar's background is drawn, 0 to 1; below 1 the wallpaper shows through, blurred |

Each falls back to a mix of the text colour, which is what every theme had before, so a
theme without them still works. The mix is a different colour on every background, though
-- muddy on Nord's lighter bar -- which is why the three themes here name their own.
`popup` takes `hover` and `border` the same way.

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

The browsers are themed from `shell.json` by `desktop-browser-theme`, which
`desktop-theme-set` runs; each shows the change the next time it starts:

- Brave and Chromium load a generated theme (`~/.local/state/desktop/browser-theme/chromium`)
  through their own launcher entries, copies in `~/.local/share/applications` with
  `--load-extension` added. Brave ignores Chromium's colour setting, so a theme is the one
  way in; and recent Chromium needs `--disable-features=DisableLoadExtensionCommandLineSwitch`
  to take `--load-extension` at all. A launcher entry of your own by that name is left
  alone. Started by typing the command at a prompt, the browser goes without the theme
  until it is next started through the launcher, the menu or a link.
- Firefox gets a `desktop-theme.css` in each profile's `chrome/`, imported at the top of
  `userChrome.css` (one of your own is kept beneath it), with the desktop font for its tabs
  and menus, and `toolkit.legacyUserProfileCustomizations.stylesheets` set in `user.js` so
  that it reads it.
- The web GUIs' browser (`desktop-guis`, see [guis.md](guis.md)) wears the same theme.

`chromium.theme` is a leftover from Omarchy, read by nothing here.

k9s reads its skin through `~/.config/k9s/skins/desktop.yaml`, a link to the theme's
`k9s.yaml`, named as `ui.skin` in k9s's own config. A running k9s keeps the skin it started
with; the next one has the new theme. The skins are in the colours of the theme's
`tmux.conf`, on the terminal's own background, so a cluster session's k9s window matches
tmux and argo9s beside it (argo9s has fixed colours and no skins).

## Adding a theme

Copy an existing directory and change the colours. Both `hyprland.conf` and
`hyprland.lua` are needed: `test/hypr-lua-test.sh` verifies the Lua config once per theme.
