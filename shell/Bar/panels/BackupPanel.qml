import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Backup panel: when the last copy left this machine, and the way back to a file.
//
// Snapper's snapshots undo a bad upgrade, but they live on the same LUKS volume as the
// data, so they answer "I broke it" and not "the disk died". This panel is about the
// copy that leaves -- restic, over sftp, to the NAS -- which is also the one nobody
// notices has stopped running. Hence the age of the last backup as the headline: not
// whether backups are configured, but whether one actually happened lately.
//
// Laid out like the battery panel: how long since the last copy left, big, and the state
// in words under the title. There is no schedule -- a backup runs when it is started --
// and the panel says so, because a backup that everyone assumes is automatic is the kind
// that stops without anyone noticing.
//
// Restoring is deliberately not a button. The common need is one file from last
// Tuesday, so "Browse" mounts the repository read-only and hands it to the file
// manager, where picking the wrong thing cannot overwrite the right one.
Popup {
  id: root

  readonly property string panelId: "backup"

  property string state: "unconfigured"
  property string repository: ""
  property string host: ""
  property string lastAge: "never"
  property string lastSnapshot: ""
  property var snapshots: []

  readonly property var stateText: ({
      "ok": "up to date",
      "stale": "overdue",
      "never": "never run",
      "running": "running now",
      "unreachable": "cannot reach the repository",
      "unconfigured": "not set up"
    })

  property real lastAt: 0

  // "3 days ago" in the status line, "3d" in the big number.
  function shortAge(seconds) {
    if (!seconds)
      return "never";
    var minutes = Math.floor((Date.now() / 1000 - seconds) / 60);
    if (minutes < 60)
      return minutes + "m";
    if (minutes < 60 * 48)
      return Math.floor(minutes / 60) + "h";
    return Math.floor(minutes / 1440) + "d";
  }

  function tone(name) {
    if (name === "stale" || name === "never")
      return Color.popupUrgent;
    if (name === "running" || name === "unconfigured")
      return Color.popupAccent;
    return Color.popupText;
  }

  function launch(command) {
    return {
      command: command,
      workingDirectory: Quickshell.env("HOME")
    };
  }

  Process {
    id: report

    command: ["desktop-backup", "status", "--json"]

    function reload() {
      if (!running)
        running = true;
    }

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var data = JSON.parse(text);
          root.state = data.state || "unconfigured";
          root.repository = data.repository || "";
          root.host = data.host || "";
          root.lastAge = data.lastAge || "never";
          root.lastAt = data.lastAt || 0;
          root.lastSnapshot = data.lastSnapshot || "";
          root.snapshots = data.snapshots || [];
        } catch (e) {
          root.state = "unconfigured";
        }
      }
    }
  }

  // The snapshot list behind this is cached for five minutes, so opening the panel
  // repeatedly costs nothing and an unreachable NAS answers immediately.
  Timer {
    interval: 30000
    repeat: true
    running: root.visible
    triggeredOnStart: true
    onTriggered: report.reload()
  }

  contentWidth: Style.popupWidth
  contentHeight: column.implicitHeight + Style.popupPadding * 2

  Column {
    id: column

    width: parent.width
    spacing: 2

    PanelHero {
      icon: "\u{f0167}"
      iconColor: root.tone(root.state)
      title: "Backup"
      status: root.stateText[root.state] || root.state
      statusColor: root.tone(root.state)
      spinning: root.state === "running"
      value: root.state === "unconfigured" ? "—" : root.shortAge(root.lastAt)
      valueColor: root.state === "stale" || root.state === "never" ? Color.popupUrgent : Color.popupText
    }

    Grid {
      width: parent.width
      columns: 2
      topPadding: 2
      bottomPadding: 4

      PanelStat {
        label: "Last"
        value: root.lastAge
        warn: root.state === "stale" || root.state === "never"
      }
      PanelStat {
        label: "Snapshots"
        value: root.snapshots.length > 0 ? String(root.snapshots.length) : "—"
      }
      PanelStat {
        label: "To"
        value: root.host !== "" ? root.host : "—"
      }
      PanelStat {
        label: "Reachable"
        value: root.state === "unconfigured" ? "—" : (root.state === "unreachable" ? "no" : "yes")
        warn: root.state === "unreachable"
      }
      PanelStat {
        label: "Schedule"
        value: "by hand"
        muted: true
      }
      PanelStat {
        label: "Copy of"
        value: "~"
        muted: true
      }
    }

    // Nothing has been set up yet: say what is missing rather than showing an empty
    // list and letting it look broken.
    // The one thing missing is a password file restic can read; the repository is already
    // named in backup.conf. Both are a file edit away, so the panel opens the config.
    PanelRow {
      icon: "\u{f0026}"
      label: "Set up backups"
      sublabel: "needs ~/.config/desktop/restic-password  ·  opens backup.conf"
      visible: root.state === "unconfigured"
      active: true
      onClicked: {
        root.close();
        Quickshell.execDetached(root.launch(["desktop-launch-editor", Quickshell.env("HOME") + "/.config/desktop/backup.conf"]));
      }
    }

    PanelSection {
      title: "Snapshots"
      value: root.snapshots.length > 0 ? root.snapshots.length + " kept" : ""
      rule: true
      visible: root.snapshots.length > 0
    }

    Repeater {
      model: root.snapshots.slice(0, 6)

      delegate: PanelRow {
        required property var modelData

        icon: "\u{f0193}"
        label: modelData.time
        sublabel: modelData.id + "  ·  " + (modelData.paths || []).join(", ")
        enabled: false
      }
    }

    PanelSection {
      title: "Advanced"
      rule: true
    }

    PanelRow {
      icon: "\u{f0167}"
      label: "Back up now"
      sublabel: root.state === "unreachable" ? root.host + " is not answering" : "in a terminal, so you can watch it"
      enabled: root.state !== "running"
      onClicked: {
        root.close();
        Quickshell.execDetached(root.launch(["desktop-launch-floating-terminal-with-presentation", "desktop-backup"]));
      }
    }

    PanelRow {
      icon: "\u{f0256}"
      label: "Browse snapshots"
      sublabel: "mounted read-only -- copy out what you need"
      enabled: root.snapshots.length > 0
      onClicked: {
        root.close();
        Quickshell.execDetached(root.launch(["desktop-launch-tui", "desktop-backup", "browse"]));
      }
    }
  }
}
