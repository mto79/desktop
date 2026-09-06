import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui

// Used memory, computed the way free(1) does it: total minus available. "Available" is
// the kernel's own estimate and is far closer to what is actually usable than
// total - free, which counts cache as used.
BarItem {
  id: root

  property real usedGb: 0
  property real totalGb: 0

  tooltip: totalGb > 0 ? usedGb.toFixed(1) + "G used of " + totalGb.toFixed(1) + "G" : ""

  function parse(text) {
    var total = 0;
    var available = 0;
    var lines = text.split("\n");

    for (var i = 0; i < lines.length; i++) {
      var match = lines[i].match(/^(MemTotal|MemAvailable):\s+(\d+)\s+kB/);
      if (!match)
        continue;
      if (match[1] === "MemTotal")
        total = parseInt(match[2], 10);
      else
        available = parseInt(match[2], 10);
    }

    if (total === 0)
      return;

    totalGb = total / 1048576;
    usedGb = (total - available) / 1048576;
  }

  FileView {
    id: meminfo

    path: "/proc/meminfo"
    onLoaded: root.parse(text())
  }

  Timer {
    interval: 30000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: meminfo.reload()
  }

  IconLabel {
    icon: ""
    text: root.usedGb.toFixed(1) + "G"
    color: Color.barText
  }
}
