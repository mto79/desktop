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

The right of the bar is five pills: connection, sound, agents, alerts and system. A pill is a
layout entry of `"type": "group"` with its widgets under `"widgets"`, drawn on the theme's
`bar.pill` colour. Every widget in it stays shown and nothing changes on hover: hiding some
until the pill was hovered was tried and dropped. See `shell/Bar/widgets/Group.qml`.

When a section has no room left beside the centred clock -- the laptop screen on its own --
widgets give up their text, one at a time until it fits (`shell/Bar/fit.js`), the ones inside
a pill as much as the ones outside. A widget with a
short form is shortened first: the CPU drops its graph and keeps its percentage, set by
`shortText` on its `IconLabel`. Then the one giving back the most loses its text, keeping its
glyph. `{"keepText": true}` on a widget in `shell.json` puts it last in line.

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
| Dashboard, AI tab | `desktop-dash ai` (the prompts), `desktop-dash agents` (sessions, limits, tokens), `desktop-dash rights` (what each may do) |
| Dashboard, Infrastructure tab | `desktop-dash infra` (the clusters, from `desktop-cluster status`), `desktop-dash network` (where this machine is) |

A dashboard tab can have headings of its own, changed with the up and down keys: the AI
tab has Presence, Agents, Rights, Voice commands and Prompts, the Infrastructure tab Clusters and
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
| Media | A player is playing; the equalizer takes the glyph's place while it does |
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

Their volume and mute come from `Levels` (`shell/Commons/Levels.qml`), and so do the audio
and microphone panels' and the overlay's: not from Quickshell's `audio.muted` and
`audio.volume`. Quickshell keeps its own copy of those and does not ask again after a
Bluetooth device drops and comes back, so a reconnected headset read as muted for hours.
`Levels` runs one `pactl subscribe`, and on each change to a device or to the default asks
`wpctl get-volume` what is true now. Mute buttons go through `wpctl set-mute` for the same
reason: flipping a stale copy sets the mute it already has.

Dimming a whole module, which the AI widget does when an agent waits, means "look here"
and is kept for that.

## Notifications

Every notification gets a toast, but the notification centre behind the bell keeps only
messages that still want an answer once the toast has gone: a review waiting on GitHub,
GitLab, Forgejo or Codeberg (from `desktop-reviews`), and Teams and the chat. Everything
else, such as a screenshot saved or an agent waiting, goes when its toast does. The rule
is in `shell/Notifications/kept.js`. It matches an application's name, or for a browser
notification the site named on the first line of the body. The chat's site comes from
`CHAT_URL` in `~/.config/desktop/chat.conf`, so it never appears in the repository.
`notifications.remember` in `shell.json` replaces the built-in list, and the chat's site
is still added to it.

What the centre keeps is saved to `~/.local/state/desktop/notifications.json` and read
back on restart, filtered by the same rule.

Notifications are grouped by conversation: who sent them (the application, or for a web
app the site) and their title. A group chat sends every message under the chat's name,
so its messages are one conversation, and so are a forge's about one merge request:

- A new message in a conversation already on screen replaces that toast instead of
  stacking under it, and the toast's header says how many messages the conversation holds.
  The one replaced goes where a timeout would send it. A critical toast is never replaced.
- The centre lists senders, and under each one row a conversation: its newest message, how
  many there are, and when. A click opens the newest, which opens the chat, and puts the
  rest away with it. A right click puts the whole conversation away unopened.
- The dashboard's Notifications tile lists the latest conversations the same way, from
  `desktop-brief`.

## Keeping the screen on

hypridle starts the screensaver after 15 minutes, locks after 17.5 and turns the screen
off after 18. During a call that is wrong: you are listening, not typing. `Awake`
(`shell/Commons/Awake.qml`) keeps the screen on while a microphone is recording, while
the screen is shared, and while you hold it by hand. Every bar carries a Quickshell
`IdleInhibitor` bound to it, and hypridle honours it.

The coffee cup among the toggles lights up while the screen is being kept on, and its
tooltip says why. Clicking it, or `SUPER + CTRL + I` (`desktop-toggle-idle`), holds the
screen on or lets it go again. A hold is not kept across a restart of the shell. When the
shell is not running, `desktop-toggle-idle` stops or starts hypridle instead, as it
always did.

    desktop-shell shell awake          # "on: a microphone is recording", or "off"
    desktop-shell shell toggleAwake    # "held" or "released"

A recording only counts when it is not from a speaker's monitor. `cava`, which draws the
music equalizer, records what the speakers play, and that is not a call.

## The Start tab

The dashboard's first tab is one screen of tiles, five columns by three rows with a dock
under them, fitted to what is left of the window under the tabs. On a screen too short for
that, the tiles keep a height they can be read at and the page scrolls.

| Tile | From |
|---|---|
| System: CPU, memory, temperature, disk | `desktop-brief` (`/proc`, `desktop-status-cpu`, `df`) |
| Claude: the session and the week | `desktop-brief` (`desktop-status-claude`) |
| Weather | `desktop-weather`, through the brief |
| The month | `holidays.js`; today filled in, holidays ringed |
| To-do and Notes | `desktop-todo`, whose files the page watches |
| Screen time | `desktop-screentime`, through the brief (below) |
| Music | the MPRIS players, as the bar's media widget sees them |
| Headlines | the News tab's own answer, newest first across every feed |
| This machine, Notifications | `desktop-brief` |
| The dock | `~/.config/desktop/dashboard/dock` |

A ring is coloured by how full it is (`Color.gauge`), so one at 90% says so before its
number is read.

Typing in the to-do field or the note takes the keyboard from the tab keys, so a `1` is
written there and does not change tab. Escape gives the keys back. In the to-do list, a
click ticks an item off and a right-click removes it.

The weather needs a place, written once:

    mkdir -p ~/.config/desktop/dashboard
    echo 'place = Utrecht' > ~/.config/desktop/dashboard/weather.conf

A name is looked up once with Open-Meteo's geocoding and remembered. A name can belong to
more than one town ("Den Haag" alone finds one in South Africa), so a `country = NL` line
narrows the lookup to that country. `latitude =` and `longitude =` lines skip the lookup. Open-Meteo needs no account and is told only the
coordinates. Until a place is set, the tile is labelled "sample", says what to write, and
shows invented weather.

The dock lists desktop entries by id, one a line, such as `brave-browser` or
`org.keepassxc.KeePassXC` (the file name without `.desktop`). Without the file it shows
a browser, Ghostty, Files, Obsidian, KeePassXC, Claude and Calculator.

## Screen time

The dashboard's Start tab has a Screen time tile: today's total, the last seven days as
bars, and today's apps. `desktop-screentime.timer` runs `desktop-screentime record` every
minute, and the minute counts when the screen is unlocked and something was touched in the
five minutes before it. A fourth hypridle listener marks those five minutes by putting
`$XDG_RUNTIME_DIR/desktop-idle` down, and takes it away again on input. A call holds the
screen awake (see above), so hypridle leaves no mark and a call counts as screen time.

What is written down is the class of the window in front, made readable. Everything in a
terminal is "Terminal", because Ghostty cannot set a class of its own, and a web app is its
site. There is a file per day, a line per minute, in
`~/.local/state/desktop/screentime/`. The files are kept for 60 days and never leave the
machine.

    desktop-screentime --json      # today, the week and today's apps; what the card draws

## The Security tab

The dashboard's Security tab has four headings:

- **Posture** draws `desktop-security check`: what needs looking at, the machine's facts,
  and what passed.
- **Events** draws `desktop-security-events`: alerts, a timeline, the rules with their
  counts, and a search. Words narrow it, and `severity:high`, `rule:sudo-denied`,
  `source:kernel` and a leading `-` for "not" work too. A click on a rule searches for it.
- **Scanner** is a 3D globe, from `desktop-scanner`.
- **Advisories** is NCSC-NL's security advisories, from `desktop-advisories`.

| Layer | Source | Needs |
|---|---|---|
| Aircraft | OpenSky | Nothing, but an anonymous caller gets about 100 asks a day |
| Ships | Digitraffic | Nothing, but it only covers the Baltic |
| Malware C2 | Feodo Tracker and C2IntelFeeds, placed by ip-api | Nothing |
| Earthquakes | USGS | Nothing |
| Wi-Fi | WiGLE | An account, and where home is |
| Natural events | NASA EONET | Nothing: wildfires, storms, volcanoes and sea ice going on now |
| Aircraft, live | adsb.lol | Nothing; zoomed in to a region, every 10 seconds |
| Webcams | Windy | A free key; shown once zoomed in to a region |

For WiGLE, store `name:token` from wigle.net/account and say where home is:

    secret-tool store --label="WiGLE" service desktop-dashboard account wigle
    echo '{"home": {"lat": 52.0, "lon": 5.0}}' > ~/.config/desktop/dashboard/scanner.json

Scroll zooms from orbit down to about 160 km up, and a double-click goes to a place and
three times closer. A click on an aircraft asks `desktop-scanner --aircraft` for what
hexdb.io knows about it: its type, registration, owner and the route its callsign usually
flies, which can be out of date. It also offers a link to follow it live.

Zoomed in to a region, aircraft come from adsb.lol instead, every ten seconds, within as
much of the view as its limit of 250 nautical miles allows. OpenSky's five-minute-old
aircraft are hidden meanwhile, so a plane is not drawn twice. A click on one asks hexdb.io
about it, as for OpenSky's. adsb.lol's data is under the ODbL, which the layer list credits.

Webcams are asked for around the middle of the view once it has been still for a moment and
is zoomed in to a region, within Windy's limit of 250 km. Only cameras their owners
registered with Windy are shown. A click on a dot or a thumbnail opens a pop-up over the
globe, with the picture at the size Windy serves it, how old it is, and the day's timelapse.
The timelapse is Windy's own player in a web app window that floats over the dashboard
(`default/hypr/apps/webcams.lua`). It cannot play inside the shell, because QtWebEngine
crashes Quickshell. Linking each picture to that player is also what Windy's terms ask,
along with their credit, which sits under the pictures.

They are fetched from further out than they are shown (`preloadFrom`), so they are already
there, thumbnails included, when the view comes close enough. A view that moved only a
little, within a radius already asked about and while the links still work, is not asked
about again. The same goes for live aircraft between their ten-second asks. Windy's picture links expire after 10–15 minutes, so a copy
is kept for 8. For the key:

    secret-tool store --label="Windy" service desktop-dashboard account windy

Each feed has an age limit, and one that is down keeps its last copy and says so. Nothing
is fetched unless the heading is on show. The globe is a QtQuick3D scene loaded by a
`Loader`, so it only costs anything while it is on screen, and a machine without
`qt6-qtquick3d` loses the globe rather than the shell. The dots come from a file per layer
(`FileInstancing`), which is one draw call however many there are. `Globe.qml` must stay
the only file importing QtQuick3D, or that protection is gone.

A frame only costs something when something changed, so the globe keeps still whenever it
can. It turns only when nobody is using it: not with a dot chosen, not zoomed in, and not
for more than a minute after the last touch. Nothing in the scene may animate forever,
because one endless animation redraws the whole planet at the monitor's refresh rate.

**Advisories** draws `desktop-advisories`: what NCSC-NL has published, with its rating of
likelihood and damage. A click opens the summary and a link to the advisory. "Yours" means
an advisory names something installed here, as a package or a command, or on your own list.
It does not say your version is affected. Your own list is for what this machine cannot
know about, and stays out of the repository:

    echo '{"watch": ["OpenShift", "Kubernetes"]}' > ~/.config/desktop/dashboard/advisories.json

A high/high advisory from the last fortnight that names something of yours puts a dot on the
tab. The feed is asked at most every half hour, and the last copy stays if it cannot be
reached.

While the screen is shared, the events, the Wi-Fi around you and the home marker are not
drawn.

The texture is NASA's Black Marble 2016, public domain.

## Music

While a player plays, the media widget's glyph becomes an equalizer: a dozen bars, bass
to treble, from `cava` listening to PipeWire. `Spectrum` (`shell/Commons/Spectrum.qml`)
runs the one cava for every monitor, with `default/cava/spectrum.conf`, and stops it on
pause. Without cava the glyph stays, so the widget works either way.

When a new track starts, `shell/NowPlaying/` raises a card under the bar: the cover,
the track, and the artist's studio albums with the one playing lit. The albums come from
`desktop-discography`, which asks MusicBrainz and keeps the answer and the covers a month
in `~/.cache/desktop/discography/`; an artist with no album yet shows EPs and singles,
and one MusicBrainz does not know gets the card without a discography. Hovering holds the
card, a click opens the media panel, a right click puts it away. It stays down while do
not disturb is on, and the track that is playing when the shell starts does not count as
new.

`desktop-shell shell nowPlaying` shows it for the track already playing. In
`shell.json`, `nowPlaying` takes `enabled`, `position`, `margin` and `timeout`.

## Adding a panel

1. A `Popup` in `shell/Bar/panels/` with `readonly property string panelId`.
2. Register it in `shell/Bar/Bar.qml`.
3. Have its widget open it with `popups.toggle(root.panelId, this)`.
4. Add a letter for it to the `panels` submap in `default/hypr/bindings/utilities.lua`,
   and its `.conf` twin.
5. `desktop-restart-shell`, then `desktop-shell shell togglePanel <id>`.

## Rules that are easy to break

- **A status script on a timer goes through `Polls`** (`shell/Commons/Polls.qml`), not a
  `Timer` and `Process` in the widget. A bar widget exists once per monitor, so its own
  poll runs once per monitor, and that once cost a third of a core on three screens. Join
  in `Component.onCompleted`, never in a binding, or it joins again each time the list of
  polls changes. `Polls` also stops asking when the machine has been idle for five minutes.

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
