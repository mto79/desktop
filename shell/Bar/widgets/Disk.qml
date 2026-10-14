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

  // Megabytes a second read and written, over every whole disk: which one / is on is not
  // worth working out for a light that says "the disks are busy".
  property real rate: 0
  property real lastBytes: -1
  property real lastTime: 0
  readonly property bool busy: rate >= 10
  readonly property bool full: parseInt(usedPercent, 10) >= 90

  function sample(text) {
    var bytes = 0;
    var lines = text.split("\n");
    for (var i = 0; i < lines.length; i++) {
      var f = lines[i].trim().split(/\s+/);
      // Whole disks only: a partition's sectors are its disk's too.
      if (f.length > 9 && /^(nvme\d+n\d+|sd[a-z]+|vd[a-z]+|mmcblk\d+)$/.test(f[2]))
        bytes += ((parseInt(f[5], 10) || 0) + (parseInt(f[9], 10) || 0)) * 512;
    }
    var now = Date.now();
    if (lastBytes >= 0 && now > lastTime)
      rate = (bytes - lastBytes) / 1048576 / ((now - lastTime) / 1000);
    lastBytes = bytes;
    lastTime = now;
  }

  FileView {
    id: diskstats

    path: "/proc/diskstats"
    onLoaded: root.sample(text())
  }

  Timer {
    interval: 2000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: diskstats.reload()
  }

  tooltip: free === "" ? "" : free + " free of " + size + " (" + usedPercent + " used)\non " + path + (busy ? "\n" + Math.round(rate) + " MB/s read and written" : "")

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
    // Nearly full is a warning whatever the disks are doing; busy is only worth the light.
    color: root.full ? Color.barUrgent : (root.busy ? Color.barAccent : Color.barText)
    lively: root.busy
  }
}
