---
name: shell-dev
description: Editing the Quickshell desktop shell under shell/ - bar widgets, panels, notifications, the launcher. Read before changing any QML, and before trying to read shell logs.
---

# Shell development

The shell is one long-running Quickshell process started by `desktop-launch-shell`,
which supervises it and falls back to waybar + mako if it will not stay up. Never start
a second instance for a component.

Apply QML changes with `desktop-restart-shell`. It kills every existing instance in a
loop, relaunches, waits for the new one to answer IPC, then retires the fallback.

## Reading logs — the part that wastes the most time

```bash
journalctl --user -t desktop-shell -n 20
```

`desktop-launch-shell` pipes the shell through `systemd-cat -t desktop-shell`, so the
journal is the authoritative place. Two traps:

- The subcommand is `quickshell log <file>`, **not** `quickshell log read <file>`. The
  wrong form prints an error to stderr and nothing to stdout, so a grep over it looks
  exactly like "no warnings" — a silent false negative.
- `console.log` does not appear. `console.warn` does. Use warn for temporary probes.

Confirm the shell is alive with `desktop-shell shell ping` → `ok`.

## Panels

A panel is a `Popup` in `shell/Bar/panels/`, with `readonly property string panelId`.
Register it in `shell/Bar/Bar.qml`:

```qml
MemoryPanel {
  Component.onCompleted: popupHost.register(panelId, this)
  onDismissed: popupHost.notifyClosed(panelId)
}
```

Its bar widget opens it with `panelId` plus `onClicked: popups.toggle(root.panelId, this)`.

Test without clicking:

```bash
desktop-shell shell togglePanel memory     # "ok" = registered, "unknown" = not
```

Panels are keyboard-reachable through the `panels` submap: `SUPER+D` then a letter.
Adding a panel means adding it there too — see `default/hypr/bindings/utilities.conf`,
and note the closing `submap = reset`, without which every binding in the thirteen files
sourced afterwards lands inside the submap.

## Rules that are easy to break

- **Poll only while visible.** `running: root.visible` on timers, and a `Binding` with
  `when:` for anything that costs power — the network panel's Wi-Fi scan and the
  bluetooth panel's discovery both do this. Without `when:`, closing the panel leaves
  the radio scanning.
- **One handler per signal.** Adding a second `onNotification` where one exists fails
  the whole file with `Property value set multiple times`, and the shell will not load.
- **Debounce model-driven Repeaters.** Rebuilding one from inside its own model's change
  signal crashes. `AudioPanel`, `NetworkPanel` and `BluetoothPanel` each keep a
  snapshot behind a short timer.
- **A new `shell/Ui/` component needs a line in `shell/Ui/qmldir`.**
- **Quickshell services start when something binds to them.** Reading
  `Bluetooth.devices` inside a handler returns nothing; read it through a declarative
  property.

## Style

Sizes and spacing come from `shell/Commons/Style.qml`, colours from `Color.qml`. Do not
hardcode either. `itemPaddingH` is the gap inside a widget group, `barGroupSpacing` the
gap a `spacer` leaves between groups.
