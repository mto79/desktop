# Web GUIs

The web GUIs of what you are working on, ready on workspace 1: a cluster's console, its
Argo CDs, Grafana and the rest, as tabs in one browser window per cluster, opened when you
sign in to the cluster and closed when you sign out. On workspace 1 they are one Hyprland
group, a tab each. A home window, with whatever you always want, opens at login and is the
first tab.

    desktop-guis open <group>     a browser window with the group's links as tabs
    desktop-guis close <group>    that window closed
    desktop-guis list             the groups, which are open, how many links
    desktop-guis import <url>     the clusters' groups from a Homer dashboard

## The groups

`~/.config/desktop/guis.conf`, a section per group and a link a line, the URL and then a
name of your own (the tab shows the page's title):

    [home]
    https://git.example/                            GitLab

    [ocp203]
    https://console-openshift-console.apps.ocp203.example/   OpenShift
    https://argocd.ocp203.example/                           System Argo CD

A group named after a cluster in `clusters.conf` is opened by `ocl` when you sign in to it
and when its session is opened (`prefix + K`, Enter in the sidebar), and closed by
`ocl logout`. `[home]` is opened at login. A link commented out with `#` is kept but not
opened.

`desktop-guis import https://homer.example/` reads a Homer dashboard's
`assets/config.yml` and makes each section named after a cluster -- "OCP203 | Production"
-- that cluster's group, with every link in it. The groups that are no cluster's, `[home]`
first, are kept as they are; run it again when the dashboard changes.

The file is never in the repository: it names hosts, and the repository is public.

## One group on workspace 1

Each group is a browser window of its own, named after the group (`--window-name`), and on
workspace 1 they are one Hyprland group: a tab bar reading `home | ocp202 | ocp203`, in the
theme's colours and the desktop font (`group.groupbar` in `looknfeel.lua`, its colours in
each theme's `hyprland.lua`), drawn as tmux draws its tabs.

Hyprland moves a window into a group only by focusing it -- `window = ...` is ignored for
`into_group`, and the `invade` rule and `group:auto_group` add nothing to a group on another
workspace. So the windows are put together when you arrive on workspace 1, where the focus
is going anyway: `guis.lua` runs `desktop-guis arrange` on `workspace.active` for workspace
1, and `open` runs it when workspace 1 is on screen. Until you look, they wait there side by
side; arranging never pulls you anywhere, and gives the focus back to the window that had
it. The order is guis.conf's, home first.

`hl.dsp.group.lock` is Hyprland's lock on every group at once (`lockgroups`), not one
group's: set, nothing can join any group, and every `into_group` answers "ok" and does
nothing.

The windows come from a browser profile of their own (`~/.local/state/desktop/guis/browser`),
started with the class `desktop-guis`. A window rule (`default/hypr/apps/guis.lua`) puts
every window of that class on workspace 1 without following it -- a rule on the title
would come too late, since a browser names its window only once the page has loaded. The
profile also keeps these sign-ins apart from your own browsing.

## Dressed as the desktop

Before the browser starts, `desktop-guis`:

- writes a theme for it from the current theme's `shell.json` -- the tab strip the bar's
  colour, the toolbar the theme's background, the tabs' text its foreground and muted --
  loaded with `--load-extension` (which recent Chromium needs switched back on with
  `--disable-features=DisableLoadExtensionCommandLineSwitch`). Brave ignores Chromium's own
  colour setting, so it has to be a theme;
- gives it the desktop's font (`desktop-font-current`) for its tabs and address bar,
  through a GSettings file of its own: `GSETTINGS_BACKEND=keyfile` with `XDG_CONFIG_HOME`
  pointed at it. The browser takes its interface font from GTK, which reads it there;
- sets the profile dark, opening nothing of the last session, without Brave's analytics
  notice, and without asking whether to close a window with several tabs -- the window is
  closed for you on sign-out, and would otherwise stay.

Brave keeps running in the background after its last window closes, whatever the profile
says, so `close` ends it when the last GUI window has gone. The next group starts it
afresh, in the theme and the font of the moment: a theme switched meanwhile shows then.
