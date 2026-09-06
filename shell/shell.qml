import QtQuick
import Quickshell
import Quickshell.Io

import qs.Commons

import "Bar"
import "Osd"

// Entry point for the desktop shell.
//
// Launched by bin/desktop-launch-shell as `quickshell -p $DESKTOP_PATH/shell`.
// DESKTOP_PATH comes from the uwsm session environment (config/uwsm/env), which is the
// single source of truth for this checkout -- nothing here hard-codes a home directory.
ShellRoot {
  id: shell

  property string home: Quickshell.env("HOME")
  property string desktopPath: Quickshell.env("DESKTOP_PATH")

  readonly property string userConfigPath: home + "/.config/desktop/shell.json"

  // Shared service instance. The bar receives this by property injection rather than
  // importing it as a singleton: singletons reached through a relative-path import do
  // not share state, which silently leaves each consumer with its own empty copy.
  property WidgetRegistry widgetRegistry: WidgetRegistry {}

  // Bundled fallback so the bar still renders when shell.json is missing or malformed.
  // Mirrors config/desktop/shell.json closely enough to be usable; not authoritative.
  readonly property var builtinConfig: ({
      version: 1,
      bar: {
        position: "top",
        height: 38,
        layout: {
          left: [
            {
              id: "menu"
            },
            {
              id: "workspaces"
            },
            {
              id: "window"
            }
          ],
          center: [
            {
              id: "clock"
            }
          ],
          right: [
            {
              id: "tray"
            },
            {
              id: "audio"
            },
            {
              id: "battery"
            }
          ]
        }
      }
    })

  property var config: builtinConfig
  readonly property var barConfig: (config && config.bar) ? config.bar : builtinConfig.bar

  // No deep merge: a user file that declares version 1 replaces the defaults wholesale.
  // Merging nested JSON in QML gets unreadable fast, and a half-merged layout is harder
  // to reason about than a whole one.
  function applyConfig(text) {
    var parsed = null;
    try {
      parsed = JSON.parse(text);
    } catch (e) {
      console.warn("shell: could not parse", userConfigPath, "-", e, "- using built-in config");
      config = builtinConfig;
      return;
    }

    if (!parsed || parsed.version !== 1) {
      console.warn("shell:", userConfigPath, "has no `version: 1` - using built-in config");
      config = builtinConfig;
      return;
    }

    config = parsed;
  }

  // Assigned by the toggleBarTransparency IPC method, which breaks this binding on
  // purpose: the flip is a runtime state, and the next edit of shell.json restores
  // whatever the file says.
  property bool barTransparent: shell.barConfig.transparent === true

  Binding {
    target: Style
    property: "barSize"
    value: shell.barConfig.height || 38
  }

  FileView {
    path: shell.userConfigPath
    watchChanges: true
    onLoaded: shell.applyConfig(text())
    onFileChanged: reload()
    onLoadFailed: {
      console.warn("shell: no", shell.userConfigPath, "- using built-in config");
      shell.config = shell.builtinConfig;
    }
  }

  // Single IPC entry point for the shell. Scripts reach one widget through this
  // instead of restarting the whole process:
  //
  //   desktop-shell shell refreshUpdates
  IpcHandler {
    target: "shell"

    function refreshUpdates(): void {
      Bus.updatesChanged();
    }

    // Re-read the active theme's shell.json. desktop-theme-set calls this instead of
    // restarting the shell: Color deliberately does not watch that path, because it is
    // a symlink and swapping its target does not fire an inotify watch.
    function reloadTheme(): void {
      Color.reload();
    }

    function toggleBarTransparency(): void {
      shell.barTransparent = !shell.barTransparent;
    }

    // Panels are layer surfaces now, so they no longer need a click to map -- a
    // keybinding or a script can open one:
    //
    //   bindd = SUPER, N, Network panel, exec, desktop-shell shell togglePanel network
    function togglePanel(id: string): string {
      return bar.popups.toggle(id, null) ? "ok" : "unknown";
    }

    function closePanels(): void {
      bar.popups.close();
    }

    // Volume and microphone changes are noticed on their own; brightness has to be
    // told, since sysfs does not deliver a change the way PipeWire does:
    //
    //   brightnessctl set +5% && desktop-shell shell osd brightness
    function osd(kind: string): string {
      return osdOverlay.show(kind) ? "ok" : "unknown";
    }

    // Health check, so a script can tell "shell is not running" from "call failed".
    function ping(): string {
      return "ok";
    }
  }

  Osd {
    id: osdOverlay

    config: (shell.config && shell.config.osd) ? shell.config.osd : ({})
  }

  Bar {
    id: bar

    desktopPath: shell.desktopPath
    widgetRegistry: shell.widgetRegistry
    barConfig: shell.barConfig
    transparent: shell.barTransparent
  }
}
