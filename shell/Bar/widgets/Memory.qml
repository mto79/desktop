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

  // nf-fa-memory, a memory module seen from the side. nf-md-memory was a chip, and beside
  // the processor's chip the two read as one. Override with {"id": "memory", "icon": "..."}
  // -- any glyph the bar font has, pasted straight into shell.json.
  readonly property string icon: (widgetConfig && widgetConfig.icon) ? widgetConfig.icon : "\uefc5"

  // Three quarters spoken for is when it is worth a look; nine tenths is when the kernel
  // starts to make room by throwing cache out and swapping.
  readonly property int percent: totalGb > 0 ? Math.round(usedGb / totalGb * 100) : 0

  tooltip: totalGb > 0 ? usedGb.toFixed(1) + "G used of " + totalGb.toFixed(1) + "G (" + percent + "%)" : ""

  // The headline number is the alarming one -- it counts cache as used. The panel is
  // where that gets broken down into what is actually spoken for.
  panelId: "memory"

  onClicked: if (popups)
    popups.toggle(root.panelId, this)

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

  // /proc/meminfo is the kernel answering, not a file read off a disk: cheap enough to ask
  // as often as the processor is asked, so the light comes on while it matters.
  Timer {
    interval: 5000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: meminfo.reload()
  }

  IconLabel {
    icon: root.icon
    text: root.usedGb.toFixed(1) + "G"
    color: root.percent >= 90 ? Color.barUrgent : (root.percent >= 75 ? Color.barAccent : Color.barText)
    lively: root.percent >= 75
  }
}
