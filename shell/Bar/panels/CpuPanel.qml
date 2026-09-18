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
// Laid out like the battery panel: the load big at the top, a minute of history under
// it, then the per-core strip and the numbers in a grid.
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

  // A minute of the total at two-second samples, oldest first, from when the panel
  // opened. Not kept across opens: joined to the samples of the last time, the strip
  // would draw a minute that never happened.
  property var history: []
  readonly property int historyLength: 30

  property real uptimeSeconds: 0
  property string profile: ""

  // "Intel(R) Core(TM) Ultra 9 185H" is "Core Ultra 9 185H" to a person.
  readonly property string shortModel: modelName.replace(/\((R|TM)\)/g, "").replace(/^(Intel|AMD)\s+/, "").replace(/\s+(CPU|Processor)\b.*$/, "").replace(/\s+/g, " ").trim()

  function uptimeText(seconds) {
    var days = Math.floor(seconds / 86400);
    var hours = Math.floor((seconds % 86400) / 3600);
    var minutes = Math.floor((seconds % 3600) / 60);
    if (days > 0)
      return days + "d " + hours + "h";
    return hours > 0 ? hours + "h " + minutes + "m" : minutes + "m";
  }

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
          if (dt > 0) {
            usage = Math.round((1 - (idle - lastIdle) / dt) * 100);
            history = history.concat([usage]).slice(-historyLength);
          }
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

  FileView {
    id: uptime

    path: "/proc/uptime"
    onLoaded: root.uptimeSeconds = parseFloat(text().split(" ")[0]) || 0
  }

  // The power profile caps what the CPU may do, so it belongs next to what it is doing;
  // the battery panel is where it is changed.
  Process {
    id: profileProbe

    command: ["powerprofilesctl", "get"]

    function reload() {
      if (!running)
        running = true;
    }

    stdout: StdioCollector {
      onStreamFinished: root.profile = text.trim()
    }
  }

  // Summed by command, for the reason MemoryPanel spells out: brave is a dozen
  // processes and five rows of "brave" answer nothing.
  //
  // top's second sample, not ps: ps reports each process's average since it started, so
  // a browser opened this morning that has just begun spinning looked idle. top's first
  // sample has the same flaw; the second covers the one second between them.
  Process {
    id: processProbe

    command: ["bash", "-c", "top -b -n 2 -d 1 -w 512 -o %CPU | awk '/^top -/ { block++ } block == 2 && /^ *PID/ { on = 1; next } on && NF >= 12 { print $9, $12 }'"]

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
      root.history = [];
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
      profileProbe.reload();
      uptime.reload();
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

    // --- How busy, big ----------------------------------------------------------------
    Item {
      width: parent.width
      height: 56

      Text {
        id: heroIcon

        anchors.left: parent.left
        anchors.leftMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        text: "\u{f0ee0}"
        color: Color.popupText
        font.family: Style.fontFamily
        font.pixelSize: Style.iconSize * 2.4
      }

      Column {
        anchors.left: heroIcon.right
        anchors.leftMargin: 12
        anchors.right: heroUsage.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Text {
          width: parent.width
          text: root.shortModel !== "" ? root.shortModel : "CPU"
          color: Color.popupText
          font.family: Style.fontFamily
          font.pixelSize: Style.fontSize + 2
          font.bold: true
          elide: Text.ElideRight
        }

        Text {
          width: parent.width
          text: {
            var parts = [];
            if (root.threadCount > 0)
              parts.push(root.threadCount + " threads");
            if (root.freqMhz > 0)
              parts.push((root.freqMhz / 1000).toFixed(1) + " GHz");
            if (root.tempC > 0)
              parts.push(Math.round(root.tempC) + "°C");
            return parts.join("  ·  ").toUpperCase();
          }
          color: root.tempC >= 85 ? Color.popupUrgent : Color.popupMuted
          font.family: Style.fontFamily
          font.pixelSize: Style.fontSize - 2
          font.bold: true
          font.letterSpacing: 1
          elide: Text.ElideRight
        }
      }

      Text {
        id: heroUsage

        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        text: root.usage + "%"
        color: root.usage >= 90 ? Color.popupUrgent : Color.popupText
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSize * 2.2
        font.bold: true
      }
    }

    // The last minute, as columns: whether the number at the top is a spike or the
    // normal state of things, which one reading cannot say.
    Item {
      width: parent.width
      height: 44

      Row {
        id: historyStrip

        anchors.left: parent.left
        anchors.leftMargin: 6
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        height: 36
        spacing: 2
        layoutDirection: Qt.RightToLeft

        // Right to left, newest at the right edge, so the strip fills in from where the
        // eye expects "now" to be.
        Repeater {
          model: root.history.slice().reverse()

          delegate: Rectangle {
            required property var modelData

            width: (historyStrip.width - (root.historyLength - 1) * historyStrip.spacing) / root.historyLength
            height: Math.max(2, historyStrip.height * modelData / 100)
            anchors.bottom: parent.bottom
            radius: 1
            color: modelData >= 85 ? Color.popupUrgent : Color.popupAccent
            opacity: 0.85
          }
        }
      }

      Rectangle {
        anchors.left: historyStrip.left
        anchors.right: historyStrip.right
        anchors.bottom: historyStrip.bottom
        height: 1
        color: Color.popupBorder
      }

      Text {
        visible: root.history.length < 2
        anchors.centerIn: historyStrip
        text: "the last minute fills in here"
        color: Color.popupMuted
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSize - 3
      }
    }

    // One bar per hardware thread. An average hides the difference between a machine
    // that is busy and a machine with one runaway thread; this does not.
    PanelSection {
      title: "Per thread"
      value: root.threadCount > 0 ? root.threadCount + " threads" : ""
      rule: true
      visible: root.coreUsage.length > 0
    }

    Item {
      width: parent.width
      height: 34
      visible: root.coreUsage.length > 0

      Row {
        id: coreStrip

        anchors.left: parent.left
        anchors.leftMargin: 6
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        height: 26
        spacing: 2

        Repeater {
          model: root.coreUsage

          delegate: Item {
            required property var modelData

            width: (coreStrip.width - (root.coreUsage.length - 1) * coreStrip.spacing) / root.coreUsage.length
            height: coreStrip.height

            Rectangle {
              anchors.fill: parent
              radius: 1
              color: Color.popupHover
            }

            Rectangle {
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.bottom: parent.bottom
              height: parent.height * Math.max(0, Math.min(100, parent.modelData)) / 100
              radius: 1
              color: root.coreColor(parent.modelData)
            }
          }
        }
      }
    }

    Grid {
      width: parent.width
      columns: 2
      topPadding: 4
      bottomPadding: 4

      Stat {
        label: "Load"
        value: root.loadAvg !== "" ? root.loadAvg.split("  ")[0] : "—"
      }
      Stat {
        label: "5 / 15 min"
        value: root.loadAvg !== "" ? root.loadAvg.split("  ").slice(1).join(" ") : "—"
      }
      Stat {
        label: "Runnable"
        value: root.runningThreads !== "" ? root.runningThreads.split("/")[0] : "—"
      }
      Stat {
        label: "Threads"
        value: root.runningThreads !== "" ? root.runningThreads.split("/")[1] : "—"
      }
      Stat {
        label: "Up"
        value: root.uptimeSeconds > 0 ? root.uptimeText(root.uptimeSeconds) : "—"
      }
      Stat {
        label: "Profile"
        value: root.profile === "power-saver" ? "saver" : (root.profile || "—")
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

  component Stat: Item {
    property string label: ""
    property string value: ""

    width: column.width / 2
    height: 22

    Text {
      anchors.left: parent.left
      anchors.leftMargin: 6
      anchors.verticalCenter: parent.verticalCenter
      text: parent.label
      color: Color.popupMuted
      font.family: Style.fontFamily
      font.pixelSize: Style.fontSize - 1
    }

    Text {
      anchors.right: parent.right
      anchors.rightMargin: 10
      anchors.verticalCenter: parent.verticalCenter
      text: parent.value
      color: Color.popupText
      font.family: Style.fontFamily
      font.pixelSize: Style.fontSize - 1
    }
  }
}
