# Changelog

What changed, and when, in terms of what the desktop does rather than which files moved.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). There are
no releases: the desktop is updated in place by `desktop-update`, so entries are grouped
by month, newest first. The commit messages carry the reasoning; this is the map between
them.

Add a line under the current month in the same commit as the change it describes.

## 2026-10

### Added

- An equalizer in place of the media widget's glyph while music plays, from cava, and a
  card under the bar when a new track starts: the cover, the track, and the artist's
  albums from MusicBrainz with the one playing lit. cava is installed.
- A scan of who else is on the network and which Wi-Fi networks are near, and of the
  Bluetooth devices near, each drawn as a radar on the dashboard, with a Bluetooth
  heading under Infrastructure and the devices in the network panel. A scan only pings
  on a network marked home, never into the VPN, and nothing is shown while the screen
  is shared.
- The boxes of the dashboard's network picture open their details: addresses, name
  servers, and the routes on each link and through the VPN.
- A popup, said aloud, when a merge or pull request waits for your review, from every
  GitLab, GitHub, Forgejo and Gitea host that glab, gh or tea is logged in to. tea is
  installed, pinned to a version and checksum.
- Bar icons that light up while their thing is working: the microphone while something
  records, the speaker while sound plays, the network under load, a busy disk, memory and
  processor under pressure, and the battery while charging.
- A changelog, and a markdownlint configuration that the documentation passes.
- A privacy check on commit: `.githooks/pre-commit` refuses a commit that adds a token, a
  real home directory, a MAC or email address, or anything on a local deny list.
- `docs/`, a page per subject, linked from the README.
- An AI tab on the dashboard, and where the machine is on the network.
- Voice commands with a choice of how far a spoken command may travel, shown on the bar.
- A headset's battery on the bar with a warning when it runs low, and its battery and
  noise cancelling in the sound panel.
- tmux opens when a terminal is opened on workspace 3.
- An overview of every workspace on `SUPER + O`.
- A clipboard history on `SUPER + V`, with images shown as pictures
  and single entries forgettable.
- Launcher modes behind a first character: sums, commands, windows and emoji.
- A power menu of tiles that asks twice and waits before it listens.
- Notifications are kept, with a bell and a centre to read them in, and survive a restart
  of the shell.
- The bar turns green when an agent has finished and nobody has looked; it is told when
  an agent waits.
- A panel of every task in every repository.
- The Claude limits are coloured by how much of each is left.
- tmux sessions, tabs and tasks come back after a reboot.
- A sidebar column of sessions, windows and agents on `prefix + e`,
  with an AI column that has the full height, tabs that tell themselves apart, the
  limits on its bar, and `prefix + x` to close a tab.
- Terminal tabs, and a key to finish a task.
- A task in a worktree opens as a tab of the AI column that asked for it, and its agent
  says whose task it is working on.
- Agent notifications say which agent they are from.
- systemd-oomd may kill a runaway process before it takes the desktop with it.
- openbao, and the Red Hat Training Lab Connector, which opens in Ghostty.

### Changed

- Hyprland reads its Lua configuration, ahead of 0.57, which reads nothing else. The
  scripts, the bar and hypridle speak the Lua dispatchers; a session must be started
  again for the switch, and until then they are refused.
- One meaning per colour on the bar: the accent means "working", the theme's yellow means
  "look at this" -- notifications, updates, findings, a low battery.
- Memory has a module icon of its own instead of a second chip beside the processor.
- The logo is redrawn as a solid wordmark at twice the size, also on machines that are
  already installed.
- The LazyVim logo is gone from the Neovim start screen.
- The tasks count is off the bar.
- oc stays on the newest release of one minor version.
- The columns' tmux sessions are kept out of `prefix + s`.

### Fixed

- opencode starts again when its renderer dies, back into the same conversation.
- Starship no longer warns about a slow directory scan when a terminal starts cold.
- The VPN voice model shows as available whenever the VPN is up, whatever mode is chosen.
- The microphone indicator read a stream's direction backwards and lit up for music.
- The laptop screen no longer flickers while the bar moves.
- bluetoothd is brought back when it crashes.
- opencode runs without the JIT, so a SIGILL no longer kills its pane.
- The dashboard stays filled while the pointer is on another screen.
- The clock stays on the middle of the bar.
- One key press no longer both starts and cancels the screenshot picker.
- A worktree's branch is named in full, so a file in `.git` cannot shadow it.
- A failed nudge from tmux to the bar no longer prints in the pane.
- The reboot check reads the initramfs listing whole before searching it.
- rhtlc finds Firefox's profiles.
- One machine's own settings are kept out of the repository.
- Two tests no longer fail for reasons that are not the code's.

## 2026-09

The month the desktop got its own shell. Waybar, mako and wofi were replaced by a
Quickshell bar, notification server and launcher, and most of what was a terminal
command became a panel.

### Added

- The Quickshell desktop shell: a bar with grouped, pluggable widgets, tooltips that name
  the key behind an icon, and panels that grow out of the bar and open from the keyboard
  and over IPC.
- Panels for network (with joining secured networks, connection details and a speed
  test), VPN, Bluetooth (device cards with battery), sound and microphone, battery and
  power profile, monitors (drawn where they are), updates, storage, CPU (per thread, with
  a minute of history), memory (with pressure), backup, media (cover first), calendar
  (today on top, Dutch public holidays, a chosen first weekday), AI usage, screen
  recording, dictation and meeting capture.
- A notification server with toasts and do not disturb, in place of mako; web
  notifications show the site rather than the browser.
- An application launcher in place of wofi, and the desktop menu and keybindings list
  rendered in the shell.
- A volume and brightness OSD, fed by the media keys.
- A system tray in the bar font that raises the application and can tint its icons.
- Rounded corners, windows included.
- Coding agents: claude, codex and opencode run through `desktop-agent`, with Claude
  usage and burned tokens per day in the bar and AI panel, a badge for agents waiting
  on you, their state on the tmux tab, notifications only when needed, and a jump to
  any agent from every tmux status bar.
- `SUPER + A` to ask an agent from anywhere.
- A tmux layout for a coding agent, with the agent swappable in place.
- Tasks that each run in their own worktree, branch and window.
- Dictation on Right Alt through voxtype, ducking the music while you talk.
- Meeting capture of both sides of a call, transcribed locally, with a bar button and a
  key.
- A security check with verdicts, a panel, and a notification when it matters.
- `desktop-update` checks the machine will boot before offering to reboot.
- Workspaces pinned to screens, workspace 3 on the widest screen on the desk, and the
  day's windows opened at login.
- The screen is left alone for fifteen minutes before idle takes it.
- Shell history in atuin.
- A side-by-side diff of the current file with another in Neovim.
- The Hyprland configuration in Lua, alongside the `.conf` files.
- The AWS CLI, verified before it runs as root; gdu as the disk usage analyser; the NA
  model service as an opencode provider.
- tmux and gdu styled from the active theme.
- `./test/all`, a test suite seeded with the bugs it was written to stop, which treats a
  test file that runs no checks as a failure.
- `CLAUDE.md` and skills that teach agents the conventions they had been inferring.

### Changed

- Ghostty is the only terminal; Alacritty and WezTerm are gone.
- The Hyprland stack is built from a copr that still builds it, with the window and
  layer rules on the 0.53 syntax.
- The lazygit helpers live in `bin/` as `desktop-git-*`, and the commit helper says what
  went wrong and carries out a split.
- Signal comes from Flathub.

### Fixed

- A clean install no longer falls into the gaps the running machine had papered over:
  missing packages, misnamed packages, the NVIDIA driver and its signing key, vault, and
  KeePassXC Quick Unlock.
- `~/.local/bin` and `~/.cargo/bin` are on the desktop's `PATH`.
- Rust crates build against their own lockfiles.
- AppImage windows are placed by class, so they survive a re-login.
- Screenshots freeze the screen, create their folder, and say where they went.
- The yazi tokyo-night flavour was discarded on every launch.
- `desktop-tui-install` no longer destroys the icon it is given.
- `desktop-status-openvpn` reports NetworkManager VPNs.
- Brightness moves the backlight the screen is actually attached to.
- voxtype no longer enables VAD, which hid a muted microphone.
- Each Claude response is counted once.
- The polkit agent's dialog draws with a style Qt ships.
- `desktop-migrate` runs nothing when there are no migrations.
- The firewall check no longer prompts for a fingerprint.
- A screen the monitor layout left asleep is woken.

## 2026-04

### Added

- Obsidian as an AppImage with an auto-update timer, its icon taken from the AppImage.
- WireGuard.
- The NVIDIA driver installer.

### Changed

- An opaque base window rule in Hyprland.

## 2026-03

### Added

- Battery status and a binding for it.
- A tmux shortcut for a new, named session.
- fish aliases.
- An opencode configuration, and Zoom.
- Full OSC 52 clipboard support in Alacritty.

## 2026-02

### Added

- A monitor switcher.
- Ansible, NetworkManager, Firefox, Podman Desktop, Helm and OpenShift Local.
- Signal as a default application.

### Fixed

- Control bindings.

## 2026-01

### Added

- Signal, Bitwarden, Nextcloud, KeePassXC (opened automatically, with a shortcut),
  FileZilla, Spotify, VS Code, ClamAV, YubiKey tooling, the MinIO client, restic, oc and
  Claude Code.
- An OpenVPN launcher, run through systemd and polkit.
- voxtype for dictation, wiremix for audio, a timezone selector and web apps.
- MIME type defaults, with Brave as the default browser.
- An ssh-agent at login.

### Fixed

- The tte screensaver.
- A first install without a preferences file.
- `dnf` calls that waited for confirmation.

## 2025-12

### Added

- The first version: a Fedora + Hyprland desktop on the patterns of Omadora, with SDDM,
  Waybar, Starship, JetBrains Mono, Ghostty, yazi, fish, tmux with a sessionizer,
  Neovim, lazygit, neomutt, the GitHub and GitLab CLIs, kubectl and kubectx, Terraform,
  Brave, keychain and OpenVPN.
