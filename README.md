# Desktop

A Fedora + Hyprland desktop: a tiling compositor, a shell written in Quickshell, and a
set of small `desktop-*` commands that do the work behind every key and panel.

It is built on the patterns of Omadora and Omarchy and is deliberately its own thing:
fewer apps, fewer features, and every piece understood. It is one person's machine, kept
in public. Take ideas from it; expect to adjust it to your own preferences.

## What is in it

- **Hyprland**, started through `uwsm`, with bindings, window rules and monitor layouts
  under `default/hypr/`.
- **A Quickshell shell**: bar, panels, launcher, notifications, clipboard history,
  workspace overview, power menu, and a dashboard on workspace 6.
- **Ghostty and tmux**, with coding agents (Claude Code, opencode, Codex) in their own
  column, their state on the bar, and tasks in git worktrees.
- **Voice**: dictation, spoken commands from a fixed list, and speech, all transcribed on
  the machine.
- **System care**: backups, a security check, updates with migrations, themes.

## Requirements

- Fedora, on x86_64 or aarch64. It is developed on Fedora 44.
- A normal user with sudo; the installer refuses to run as root.
- Most packages come from the official Fedora repositories. The installer also enables
  these COPR repositories, which you should judge for yourself:
  `mineiro/hyprland` (the Hyprland stack), `errornointernet/quickshell`,
  `scottames/ghostty`, `kylegospo/grub-btrfs` and `tmichett/RHTLC`.

## Installation

1. Install Fedora with the [Everything Network Installer](https://alt.fedoraproject.org/).
   Drive encryption, a disabled root account and a privileged user are recommended.
2. Clone the repository to `~/.local/share/desktop` and run the installer:

       sudo dnf install -y git
       git clone https://github.com/mto79/desktop.git ~/.local/share/desktop
       ~/.local/share/desktop/install.sh

The installer runs five stages (preflight, packaging, config, login, post-install) and
reboots at the end. It copies `config/` over `~/.config/`, so run it on a fresh install,
not on a machine whose configuration you want to keep.
[docs/install-and-update.md](docs/install-and-update.md) has the details.

On a Wi-Fi only machine, add the `networkmanager-submodules` group during the Fedora
installation so that `nmcli` can connect before the installer runs. If the Wi-Fi device
has no driver after the Fedora install, `sudo dnf group install -y hardware-support`
from the installation media's rescue shell usually provides it.

## Usage

Log in through SDDM; the session is Hyprland under `uwsm`. A few keys to start with:

| Key | Does |
|---|---|
| `SUPER + SPACE` | Launcher |
| `SUPER + K` | Every key binding, searchable |
| `SUPER + D`, then a letter | A panel of the bar |
| `SUPER + C` | Voice command |
| `SUPER + V` | Clipboard history |

`desktop-update` updates everything: the repository, migrations, packages, Flatpaks and
firmware.

## Documentation

[docs/](docs/README.md) has a page per subject: how the repository becomes a running
session, install and update, Hyprland, the shell, agents and tmux, backups, security,
network, audio and Bluetooth, voice, themes, testing, and
[keeping private information out of a public repository](docs/privacy.md).

## Contributing

Some things may be broken. Issues and pull requests are welcome, with no promise of a
timely answer. `./test/all` runs the tests; it needs no compositor.

## License

Copyright (c) MTO79

This software is provided "AS IS" with absolutely **no guarantees**.
Use it entirely at **your own risk**.

The author takes **zero responsibility** for:

- broken systems
- lost data
- security issues
- financial loss
- or any other damage of any kind

If you use this code, **you accept full responsibility** for whatever happens.
