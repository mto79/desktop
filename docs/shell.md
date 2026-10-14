# The shell

The bar, its panels, the launcher, notifications, the on-screen display, the workspace
overview, the power menu and the dashboard are one long-running
[Quickshell](https://quickshell.org) process, written in QML under `shell/`.

## Layout

| Path | Holds |
|---|---|
| `shell/shell.qml` | The entry point |
| `shell/Bar/Bar.qml` | The bar, and where panels are registered |
| `shell/Bar/widgets/` | What sits on the bar: workspaces, clock, audio, network, battery, ... |
| `shell/Bar/panels/` | What opens from a widget: one `Popup` per subject |
| `shell/Dashboard/` | The window on workspace 6, a page per tab |
| `shell/Launcher/`, `Notifications/`, `Osd/`, `Overview/`, `Power/`, `Voice/` | One component each |
| `shell/Commons/` | Singletons: `Style`, `Color`, `Bus`, `Media`, `BluetoothBattery`, ... |
| `shell/Ui/` | Shared building blocks: `Popup`, `PanelRow`, `PanelSlider`, `BarWidget`, ... |

Which widgets the bar shows, and in what order, is `~/.config/desktop/shell.json`,
deployed from `config/desktop/shell.json`. So are the positions and sizes of the launcher,
notifications and OSD.

## Starting, restarting, falling back

`desktop-launch-shell` starts the shell and supervises it. Quickshell links against Qt's
private API and is only valid for the exact Qt minor version it was built against; on
Fedora a Qt point release regularly arrives before the COPR rebuilds. A shell that will
not stay up therefore falls back to waybar and mako instead of leaving the session bare.
That is why `config/waybar/` still exists.

    desktop-restart-shell          # after any QML change
    desktop-shell shell ping       # "ok" when it is alive

Never start a second instance to try one component.

## Driving it from a terminal

`desktop-shell <target> <function> [args...]` calls an IPC handler in the running shell.
The key bindings use exactly this, so anything a key does can be tested without the key:

    desktop-shell shell togglePanel audio     # "ok", or "unknown" if not registered
    desktop-shell shell toggleLauncher
    desktop-shell shell togglePowerMenu
    desktop-shell shell reloadTheme
    desktop-shell shell refreshUpdates

## Logs

    journalctl --user -t desktop-shell -n 20

`console.warn` appears there; `console.log` does not. The subcommand for a log file is
`quickshell log <file>`. `quickshell log read <file>` prints an error to stderr and
nothing to stdout, which looks exactly like a clean log.

## Where a widget's data comes from

A widget or panel either binds to a Quickshell service (audio, Bluetooth, UPower, the
tray) or runs a `desktop-*` command and reads its JSON:

| Shell side | Command |
|---|---|
| AI widget and panel | `desktop-status-ai`, `desktop-agent-sessions`, `desktop-agent-tokens` |
| Backup panel | `desktop-backup status --json` |
| Security widget and panel | `desktop-security check --json` |
| Network and VPN panels | `desktop-network-details`, `desktop-network-traffic`, `desktop-vpn-details` |
| Storage panel | `desktop-storage-details` |
| Battery panel | `desktop-battery-details` |
| Updates | `desktop-update-available` |
| Tasks panel | `desktop-worktree tasks --json` |
| Dashboard | `desktop-dash <tab> --json` |
| Dashboard, AI tab | `desktop-dash ai` (the prompts), `desktop-dash agents` (sessions, limits, tokens) |
| Dashboard, Infrastructure tab | `desktop-dash infra` (the clusters), `desktop-dash network` (where this machine is) |

A dashboard tab can have headings of its own, changed with the up and down keys: the AI
tab has Presence, Agents, Voice commands and Prompts, the Infrastructure tab Clusters and
Network. A heading with a command of its own is asked more often than its tab, and only
while the tab is on show. `Page Down` and `Page Up` scroll a page taller than the screen.

Under the picture, Devices on this network draws who else is on it as a radar -- the
faster a device answers, the nearer the middle; one that keeps quiet on the outer ring,
hollow -- with everything known of each device beside it, and Wi-Fi around gives the
networks in range by signal. The Bluetooth heading does the same for what is near over
Bluetooth, the rings in metres. A device keeps its direction on the radar from one scan to
the next. Both scans are `shell/Commons/Scans.qml`'s, shared with the network panel, which
lists the devices too; nothing scans by itself. `desktop-shell shell scanNetwork` and
`scanBluetooth` start one from outside.

The boxes of the network picture open their details under it, and a second click closes
them. This machine lists every connection and its addresses; Router the link, the Wi-Fi
signal, the name servers and the routes on that link, the one the VPN keeps to its own
server named as such; Internet the ways out, the one the kernel takes first; the VPN, and
Behind the VPN, every network the tunnel takes, in address order, with the gateway they
share said once. All of it is what NetworkManager and the routing table already hold.
`desktop-shell shell networkDetails vpn` opens a box from outside, which is what "show the
VPN routes" says to voice. While the screen is shared the details card says so and shows
nothing: Hyprland announces a share on its event socket, and `shell/Commons/Sharing.qml`
keeps track. A share that started before the shell did is only noticed when it ends.

Keeping the logic in a command is what lets it be tested in plain bash with stubs, without
a compositor.

## What the colours on the bar mean

One meaning each, so a colour can be read without knowing the widget:

| Colour | Role | Means | For example |
|---|---|---|---|
| White | `barText` | A value at rest | free disk, volume, battery on the way down |
| Grey | `barMuted` | Off, paused, nothing there | VPN down, media paused, no notifications |
| Blue | `barAccent` | Working right now, with the light behind it | sound playing, a recording, disk busy |
| Yellow | `barAttention` | Wants you | unread notifications, updates, a security finding, battery at 20% |
| Red | `barUrgent` | Something is wrong | battery at 10%, disk 90% full, microphone muted |
| Green | `barGood` | Something went well | VPN up, battery charging |

The microphone is red when muted and the speaker grey: a muted speaker is quiet on
purpose, while a muted microphone in a call is you talking to nobody. A theme sets the
yellow with `bar.attention` in its `shell.json`, or leaves it to its `caution` colour. A
command widget names it as `"attention"` in its `colors`.

## Icons that are in use

An icon on the bar shows when its thing is working, the way the AI orb does: it takes a
colour and a soft light breathes behind it. `IconLabel` draws it, from one property,
`lively`; a widget only says when.

| Widget | In use when |
|---|---|
| Microphone | A program is recording from it |
| Sound | Something is playing, a call in a browser as much as music |
| Media | A player is playing |
| Bluetooth | A device is connected (colour); it is searching (light) |
| VPN | A tunnel is up (green) |
| Network | More than a trickle is going through |
| Battery | It is taking charge |
| Disk | More than 10 MB/s is being read or written; red when 90% full |
| Memory | 75% or more is used; red from 90% |
| CPU | 60% or more; red from 90% |

The speaker and the microphone ask `Sound` (`shell/Commons/Sound.qml`), which looks at
PipeWire's links rather than at its streams: a browser keeps a stream for every tab that
ever played, and it is the link that goes inactive when a stream is quiet.

Dimming a whole module, which the AI widget does when an agent waits, means "look here"
and is kept for that.

## Adding a panel

1. A `Popup` in `shell/Bar/panels/` with `readonly property string panelId`.
2. Register it in `shell/Bar/Bar.qml`.
3. Have its widget open it with `popups.toggle(root.panelId, this)`.
4. Add a letter for it to the `panels` submap in `default/hypr/bindings/utilities.conf`,
   and its Lua twin.
5. `desktop-restart-shell`, then `desktop-shell shell togglePanel <id>`.

## Rules that are easy to break

- **Poll only while visible.** `running: root.visible` on timers; a `Binding` with `when:`
  for anything that costs power, or closing the panel leaves the radio scanning.
- **A bar widget exists once per monitor.** Anything that must happen once, like sending a
  notification, belongs in a `shell/Commons/` singleton.
- **One handler per signal.** A second `onNotification` fails the whole file.
- **A new `Ui/` component or `Commons/` singleton needs a line in that directory's `qmldir`.**
- **Sizes come from `Style.qml` and colours from `Color.qml`**, never hardcoded.
- **Logic worth testing goes in a plain `.js` file** beside the QML (`lowbattery.js`,
  `calc.js`, `holidays.js`) so a test can run it with node.

`.claude/skills/shell-dev/SKILL.md` has the reasons behind each, and
`.claude/skills/visual-verification/SKILL.md` how to capture and inspect the result.
