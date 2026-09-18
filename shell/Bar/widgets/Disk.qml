import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui

// Free space on the filesystem given in shell.json (default /), from df.
BarItem {
  id: root

  readonly property string path: (widgetConfig && widgetConfig.path) ? widgetConfig.path : "/"

  readonly property string icon: (widgetConfig && widgetConfig.icon) ? widgetConfig.icon : "\uf0a0"

  property string free: ""
  property string size: ""
  property string usedPercent: ""

  tooltip: free === "" ? "" : free + " free of " + size + " (" + usedPercent + " used)\non " + path

  // Left click opens the storage panel, which says where the space went and carries
  // the usage analyzer; right click still opens the file manager on the filesystem.
  panelId: "storage"

  onClicked: if (popups)
    popups.toggle(root.panelId, this)
  rightCommand: ["desktop-launch-files", root.path]

  Process {
    id: probe

    // -h for human units, --output to name the fields we want in the order we want
    // them, which skips the parsing df's default column layout would otherwise need.
    command: ["df", "-h", "--output=avail,size,pcent", root.path]

    stdout: StdioCollector {
      onStreamFinished: {
        var lines = text.trim().split("\n");
        if (lines.length < 2)
          return;
        var fields = lines[1].trim().split(/\s+/);
        root.free = fields[0] || "";
        root.size = fields[1] || "";
        root.usedPercent = fields[2] || "";
      }
    }
  }

  Timer {
    interval: 30000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!probe.running)
      probe.running = true
  }

  IconLabel {
    icon: root.icon
    text: root.free
    color: Color.barText
  }
}
