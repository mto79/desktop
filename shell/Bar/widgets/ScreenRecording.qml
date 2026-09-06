import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui

// Recording indicator, reusing the existing waybar indicator script rather than
// reimplementing the wf-recorder probe. It returns waybar-style JSON, of which only
// `text` is needed here.
//
// The path is resolved from desktopPath: the waybar config hard-coded /home/mto, which
// broke the config for anyone else.
BarItem {
  id: root

  property string label: ""

  visible: label !== ""
  implicitWidth: visible ? content.implicitWidth + Style.itemPaddingH * 2 : 0
  command: ["desktop-cmd-screenrecord"]

  Process {
    id: probe

    command: [root.desktopPath + "/default/waybar/indicators/screen-recording.sh"]

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var parsed = JSON.parse(text);
          root.label = (parsed && parsed.text) ? parsed.text : "";
        } catch (e) {
          root.label = "";
        }
      }
    }
  }

  Timer {
    interval: 2000
    running: root.desktopPath !== ""
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!probe.running)
      probe.running = true
  }

  IconLabel {
    id: content

    text: root.label
    color: Color.barUrgent
  }
}
