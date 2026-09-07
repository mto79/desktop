import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// CPU panel: how busy, how hot, how fast, and what is doing it.
//
// The bar widget shows one number and a four-sample braille history. The number a
// single figure cannot give you is the shape of the load: eleven percent across
// twenty-two threads and one thread pegged at a hundred are the same average and very
// different problems. Hence the per-core strip, which is the reason this panel exists.
//
// /proc/stat is cumulative since boot, so every usage figure here is a delta between
// two reads -- the first tick after opening has nothing to compare against and shows
// zero, exactly as the widget does.
//
// Everything polls only while the panel is open.
Popup {
  id: root

  readonly property string panelId: "cpu"

  property int usage: 0
  property var coreUsage: []

  // Cumulative counters from the previous sample, indexed the same way as coreUsage.
  property real lastTotal: 0
  property real lastIdle: 0
  property var lastCoreTotal: []
  property var lastCoreIdle: []

  property string loadAvg: ""
  property string runningThreads: ""
  property string modelName: ""
  property int threadCount: 0

  property real tempC: 0
  property real freqMhz: 0

  property var topProcesses: []

  // idle + iowait, as the widget counts them.
  function idleOf(parts) {
    return (parseInt(parts[4], 10) || 0) + (parseInt(parts[5], 10) || 0);
  }

  function totalOf(parts) {
    var total = 0;
    for (var i = 1; i < parts.length; i++)
      total += parseInt(parts[i], 10) || 0;
    return total;
  }

  function sample(text) {
    var lines = text.split("\n");
    var cores = [];
    var coreTotals = [];
    var coreIdles = [];

    for (var i = 0; i < lines.length; i++) {
      var parts = lines[i].trim().split(/\s+/);
      if (parts[0] === "cpu") {
        var total = totalOf(parts);
        var idle = idleOf(parts);
        if (lastTotal > 0) {
          var dt = total - lastTotal;
          if (dt > 0)
            usage = Math.round((1 - (idle - lastIdle) / dt) * 100);
        }
        lastTotal = total;
        lastIdle = idle;
        continue;
      }

      if (!/^cpu\d+$/.test(parts[0]))
        continue;

      var index = coreTotals.length;
      var cTotal = totalOf(parts);
      var cIdle = idleOf(parts);
      var value = 0;
      if (lastCoreTotal.length > index) {
        var cdt = cTotal - lastCoreTotal[index];
        if (cdt > 0)
          value = Math.max(0, Math.min(100, Math.round((1 - (cIdle - lastCoreIdle[index]) / cdt) * 100)));
      }
      cores.push(value);
      coreTotals.push(cTotal);
      coreIdles.push(cIdle);
    }

    lastCoreTotal = coreTotals;
    lastCoreIdle = coreIdles;
    coreUsage = cores;
    threadCount = cores.length;
  }

  FileView {
    id: stat

    path: "/proc/stat"
    onLoaded: root.sample(text())
  }

  // Four fields: the three averages, then running/total threads.
  FileView {
    id: loadavg

    path: "/proc/loadavg"
    onLoaded: {
      var parts = text().trim().split(/\s+/);
      root.loadAvg = parts.slice(0, 3).join("  ");
      root.runningThreads = parts.length > 3 ? parts[3] : "";
    }
  }

  // Read once when the panel first opens; the model does not change.
  FileView {
    id: cpuinfo

    path: "/proc/cpuinfo"
    onLoaded: {
      var m = text().match(/^model name\s*:\s*(.+)$/m);
      if (m)
        root.modelName = m[1].trim();
    }
  }

  // desktop-status-cpu finds the package sensor by type and averages the clock across
  // every thread; both paths move between machines, and neither belongs in a QML string.
  Process {
    id: sensors

    command: ["desktop-status-cpu"]

    function reload() {
      if (!running)
        running = true;
    }

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var data = JSON.parse(text);
          // Absent rather than zero when a machine has no such sensor, which is what
          // keeps the rows below hidden instead of showing a confident 0.
          root.tempC = data.tempC !== undefined ? data.tempC : 0;
          root.freqMhz = data.freqMhz !== undefined ? data.freqMhz : 0;
        } catch (e) {
          root.tempC = 0;
          root.freqMhz = 0;
        }
      }
    }
  }

  // Summed by command, for the reason MemoryPanel spells out: brave is a dozen
  // processes and five rows of "brave" answer nothing.
  Process {
    id: processProbe

    command: ["ps", "-eo", "pcpu=,comm="]

    function reload() {
      if (!running)
        running = true;
    }

    stdout: StdioCollector {
      onStreamFinished: {
        var totals = {};
        var lines = text.split("\n");
        for (var i = 0; i < lines.length; i++) {
          var m = lines[i].match(/^\s*([\d.]+)\s+(.+?)\s*$/);
          if (!m)
            continue;
          var value = parseFloat(m[1]);
          if (!(value > 0))
            continue;
          totals[m[2]] = (totals[m[2]] || 0) + value;
        }

        var list = [];
        for (var key in totals)
          list.push({
            name: key,
            pct: totals[key]
          });
        list.sort(function (a, b) {
          return b.pct - a.pct;
        });
        root.topProcesses = list.slice(0, 5);
      }
    }
  }

  onVisibleChanged: {
    if (visible) {
      // Drop the previous sample: the gap since the panel was last open would
      // otherwise be averaged into the first reading as one enormous delta.
      root.lastTotal = 0;
      root.lastCoreTotal = [];
      root.lastCoreIdle = [];
      cpuinfo.reload();
    }
  }

  Timer {
    interval: 2000
    repeat: true
    running: root.visible
    triggeredOnStart: true
    onTriggered: {
      stat.reload();
      loadavg.reload();
    }
  }

  Timer {
    interval: 3000
    repeat: true
    running: root.visible
    triggeredOnStart: true
    onTriggered: {
      sensors.reload();
      processProbe.reload();
    }
  }

  function launch(command) {
    return {
      command: command,
      workingDirectory: Quickshell.env("HOME")
    };
  }

  function coreColor(value) {
    if (value >= 85)
      return Color.popupUrgent;
    return Color.popupAccent;
  }

  contentWidth: Style.popupWidth
  contentHeight: column.implicitHeight + Style.popupPadding * 2

  Column {
    id: column

    width: parent.width
    spacing: 2

    PanelSection {
      title: "CPU"
      value: root.usage + "%"
    }

    Item {
      width: parent.width
      height: 26

      PanelMeter {
        anchors.left: parent.left
        anchors.leftMargin: 6
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        value: root.usage / 100
      }
    }

    // One bar per hardware thread. An average hides the difference between a machine
    // that is busy and a machine with one runaway thread; this does not.
    Item {
      width: parent.width
      height: 40
      visible: root.coreUsage.length > 0

      Row {
        id: coreStrip

        anchors.left: parent.left
        anchors.leftMargin: 6
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        height: 30
        spacing: 2

        Repeater {
          model: root.coreUsage

          delegate: Item {
            required property var modelData

            width: (coreStrip.width - (root.coreUsage.length - 1) * coreStrip.spacing) / root.coreUsage.length
            height: coreStrip.height

            Rectangle {
              anchors.fill: parent
              color: Color.popupHover
            }

            Rectangle {
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.bottom: parent.bottom
              height: parent.height * Math.max(0, Math.min(100, parent.modelData)) / 100
              color: root.coreColor(parent.modelData)
            }
          }
        }
      }
    }

    Item {
      width: parent.width
      height: 20
      visible: root.modelName !== ""

      Text {
        anchors.left: parent.left
        anchors.leftMargin: 6
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        text: root.modelName + (root.threadCount > 0 ? "  ·  " + root.threadCount + " threads" : "")
        color: Color.popupMuted
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSize - 2
        elide: Text.ElideRight
      }
    }

    PanelRow {
      icon: "\u{f0685}"
      label: "Load average"
      sublabel: root.runningThreads !== "" ? root.runningThreads + " runnable" : "1, 5 and 15 minutes"
      enabled: false

      Text {
        text: root.loadAvg
        color: Color.popupText
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSize - 1
      }
    }

    PanelRow {
      icon: "\u{f0322}"
      label: "Frequency"
      sublabel: "averaged across all threads"
      enabled: false
      visible: root.freqMhz > 0

      Text {
        text: (root.freqMhz / 1000).toFixed(2) + " GHz"
        color: Color.popupText
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSize - 1
      }
    }

    PanelRow {
      icon: "\u{f0e01}"
      label: "Temperature"
      sublabel: "package"
      enabled: false
      visible: root.tempC > 0

      Text {
        text: Math.round(root.tempC) + "°C"
        color: root.tempC >= 85 ? Color.popupUrgent : Color.popupText
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSize - 1
      }
    }

    PanelSection {
      title: "Top consumers"
      value: "by CPU"
      rule: true
      visible: root.topProcesses.length > 0
    }

    Repeater {
      model: root.topProcesses

      delegate: PanelRow {
        required property var modelData

        icon: "\u{f0234}"
        label: modelData.name
        // ps reports percentage of one core, so a threaded process can exceed 100;
        // dividing by the thread count gives its share of the whole machine.
        sublabel: root.threadCount > 0 ? Math.round(modelData.pct / root.threadCount) + "% of the machine" : ""
        enabled: false

        Text {
          text: modelData.pct.toFixed(0) + "%"
          color: Color.popupText
          font.family: Style.fontFamily
          font.pixelSize: Style.fontSize - 1
        }
      }
    }

    PanelSection {
      title: "Advanced"
      rule: true
    }

    PanelRow {
      icon: "\u{f01c0}"
      label: "Open btop"
      sublabel: "processes, and what to do about them"
      onClicked: {
        root.close();
        Quickshell.execDetached(root.launch(["desktop-launch-tui", "btop"]));
      }
    }
  }
}
