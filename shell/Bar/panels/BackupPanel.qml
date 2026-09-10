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

    PanelSection {
      title: "Backups"
      value: root.stateText[root.state] || root.state
    }

    PanelRow {
      icon: "\u{f0167}"
      label: "Last backup " + root.lastAge
      sublabel: root.lastSnapshot !== "" ? "snapshot " + root.lastSnapshot : "nothing has been sent yet"
      enabled: false

      Text {
        text: root.state === "running" ? "···" : ""
        color: Color.popupAccent
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSize
      }
    }

    PanelRow {
      icon: "\u{f048d}"
      label: root.host !== "" ? root.host : "no repository set"
      sublabel: root.repository
      enabled: false

      Text {
        text: root.state === "unreachable" ? "offline" : ""
        color: Color.popupMuted
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSize - 2
      }
    }

    // Nothing has been set up yet: say what is missing rather than showing an empty
    // list and letting it look broken.
    PanelRow {
      icon: "\u{f0026}"
      label: "Not set up yet"
      sublabel: "no password file yet -- see backup.conf"
      enabled: false
      visible: root.state === "unconfigured"
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
