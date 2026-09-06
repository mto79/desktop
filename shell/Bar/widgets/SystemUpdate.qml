import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui

// Shows a glyph when desktop-update-available reports an update.
//
// waybar polled hourly and was nudged early by SIGRTMIN+7 at the end of
// bin/desktop-update. Unix signals mean nothing to Quickshell, so the equivalent nudge
// arrives over IPC as Bus.updatesChanged -- which re-runs just this probe rather than
// restarting the shell for it.
BarItem {
  id: root

  property bool available: false

  visible: available
  implicitWidth: visible ? content.implicitWidth + Style.itemPaddingH * 2 : 0
  command: ["desktop-launch-floating-terminal-with-presentation", "desktop-update"]

  Process {
    id: probe

    command: ["desktop-update-available"]

    stdout: StdioCollector {
      onStreamFinished: root.available = text.trim() !== ""
    }
  }

  Connections {
    target: Bus

    function onUpdatesChanged(): void {
      if (!probe.running)
        probe.running = true;
    }
  }

  Timer {
    interval: 900000
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
