import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui

// Shows a glyph when desktop-update-available reports an update, and what the update is
// in its tooltip.
//
// waybar polled hourly and was nudged early by SIGRTMIN+7 at the end of
// bin/desktop-update. Unix signals mean nothing to Quickshell, so the equivalent nudge
// arrives over IPC as Bus.updatesChanged -- which re-runs just this probe rather than
// restarting the shell for it.
//
// The probe also sends the "updates available" notification (--notify). The script owns
// that rather than this widget because the script remembers what it already announced,
// on disk, and a shell restart must not announce it all again.
BarItem {
  id: root

  property var sources: []

  readonly property bool available: sources.length > 0

  visible: available
  implicitWidth: visible ? content.implicitWidth + Style.itemPaddingH * 2 : 0
  command: ["desktop-launch-floating-terminal-with-presentation", "desktop-update"]

  tooltip: {
    var lines = ["Updates available"];
    for (var i = 0; i < sources.length; i++)
      lines.push(sources[i].count + " " + sources[i].label);
    lines.push("", "Click to update");
    return lines.join("\n");
  }

  Process {
    id: probe

    command: ["desktop-update-available", "--json", "--notify"]

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          root.sources = JSON.parse(text).sources || [];
        } catch (e) {
          // A check that failed says nothing about updates; keep what was known.
          console.warn("SystemUpdate: unreadable output from desktop-update-available:", e);
        }
      }
    }
  }

  Connections {
    target: Bus

    function onUpdatesChanged(): void {
      if (!probe.running)
        probe.running = true;
    }
  }

  // Hourly, as waybar polled: a check refreshes dnf and fwupd metadata, which is not free,
  // and updates that waited a day would not mind another hour.
  Timer {
    interval: 3600000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!probe.running)
      probe.running = true
  }

  IconLabel {
    id: content

    icon: ""
    color: Color.barAccent
  }
}
