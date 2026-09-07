import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui

// CPU load with waybar's braille bar-graph history.
//
// /proc/stat is cumulative since boot, so usage is the delta between two reads; the
// first tick therefore has nothing to compare against and shows zero.
BarItem {
  id: root

  property int usage: 0
  property var history: [0, 0, 0, 0]

  property real lastIdle: 0
  property real lastTotal: 0

  readonly property var ramp: ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]

  readonly property string graph: {
    var out = "";
    for (var i = 0; i < history.length; i++) {
      var index = Math.min(ramp.length - 1, Math.max(0, Math.floor(history[i] / 100 * ramp.length)));
      out += ramp[index];
    }
    return out;
  }

  property string load: ""

  readonly property string icon: (widgetConfig && widgetConfig.icon) ? widgetConfig.icon : "\uf2db"

  tooltip: load === "" ? "" : usage + "% now\nload " + load

  // The braille history says how busy; the panel says which threads, how hot and what
  // is doing it.
  panelId: "cpu"

  onClicked: if (popups)
    popups.toggle(root.panelId, this)

  function sample(text) {
    var line = text.split("\n")[0];
    var parts = line.trim().split(/\s+/);
    if (parts[0] !== "cpu")
      return;

    var total = 0;
    for (var i = 1; i < parts.length; i++)
      total += parseInt(parts[i], 10) || 0;
    var idle = (parseInt(parts[4], 10) || 0) + (parseInt(parts[5], 10) || 0);

    if (lastTotal > 0) {
      var totalDelta = total - lastTotal;
      var idleDelta = idle - lastIdle;
      if (totalDelta > 0)
        usage = Math.round((1 - idleDelta / totalDelta) * 100);
    }

    lastTotal = total;
    lastIdle = idle;

    // Reassign rather than push: mutating the array in place would not re-evaluate
    // the `graph` binding.
    history = history.slice(1).concat([usage]);
  }

  FileView {
    id: stat

    path: "/proc/stat"
    onLoaded: root.sample(text())
  }

  // 1, 5 and 15 minute averages: the part of the picture a two-second delta misses.
  FileView {
    id: loadavg

    path: "/proc/loadavg"
    onLoaded: root.load = text().trim().split(/\s+/).slice(0, 3).join(" ")
  }

  Timer {
    interval: 2000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      stat.reload();
      loadavg.reload();
    }
  }

  IconLabel {
    icon: root.icon
    text: root.graph + " " + root.usage + "%"
    color: Color.barText
  }
}
