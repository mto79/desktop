# Documentation

One page per subject. Each says what the thing is for, which files it lives in, and the
commands that check it. The reasoning behind a single script is in that script's header,
and stays there; these pages are the map between them.

| Page | What it covers |
|---|---|
| [architecture.md](architecture.md) | How the repository becomes a running session: `config/` versus `default/`, what starts at login, where state is kept. |
| [install-and-update.md](install-and-update.md) | The five install stages, packages, `desktop-update`, migrations. |
| [hyprland.md](hyprland.md) | Bindings, window rules, monitors, workspaces, and the move from `.conf` to Lua. |
| [shell.md](shell.md) | The Quickshell shell: bar, panels, launcher, notifications, dashboard, and how to drive it from a terminal. |
| [agents-and-tmux.md](agents-and-tmux.md) | Coding agents, their state on the bar, tmux sessions, and tasks in worktrees. |
| [system.md](system.md) | Backups, the security check, network, storage, audio and Bluetooth. |
| [voice.md](voice.md) | Dictation, voice commands, speech, and meeting capture. |
| [themes.md](themes.md) | What a theme is made of and what switching one touches. |
| [testing.md](testing.md) | `./test/all`, how a test is written, and checking the running system. |
| [privacy.md](privacy.md) | Keeping private information out of a public repository: the hook, the deny list, and what to do when something got out. |

For working in the repository with an agent, `CLAUDE.md` holds the invariants and
`.claude/skills/` the procedures for the shell, visual checks and install scripts.
