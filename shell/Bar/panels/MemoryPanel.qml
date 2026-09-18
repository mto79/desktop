import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Memory panel: where the RAM actually went.
//
// The bar widget answers "how much is used", computed free(1)-style as total minus
// available. That number alone tends to alarm people, because Linux spends every spare
// page on cache and hands it back the moment anything wants it. So the panel splits the
// bar in two -- genuinely used, then cache -- and puts the kernel's own MemAvailable
// figure next to it, which is the only one worth reacting to.
//
// Swap on Fedora is zram: a compressed block device in RAM rather than a disk
// partition. Its interesting number is not how full it is but how well it is
// compressing, which /proc/meminfo cannot tell you -- hence the read of mm_stat.
//
// Everything polls only while the panel is open.
Popup {
  id: root

  readonly property string panelId: "memory"

  // All figures in kB, as /proc/meminfo reports them.
  property real memTotal: 0
  property real memAvailable: 0
  property real cached: 0
  property real shmem: 0
  property real swapTotal: 0
  property real swapFree: 0

  readonly property real used: Math.max(0, memTotal - memAvailable)
  readonly property real swapUsed: Math.max(0, swapTotal - swapFree)

  // Cache that is not already counted as used. MemAvailable already promises most of
  // the cache back, so drawing all of it after `used` would overflow the bar.
  readonly property real reclaimable: Math.max(0, Math.min(memTotal - used, cached - shmem))

  // zram, in bytes.
  property real zramOriginal: 0
  property real zramCompressed: 0

  // Below a few megabytes the ratio is noise -- 51x on a handful of kernel pages -- so
  // it is only claimed once there is something in zram to have compressed.
  readonly property bool zramActive: zramOriginal > 16777216 && zramCompressed > 0
  readonly property real zramRatio: zramActive ? zramOriginal / zramCompressed : 0

  property var topProcesses: []

  // The share of the last ten seconds some task spent waiting on memory -- reclaim,
  // swap-in, compaction. Used and free say how full memory is; this says whether that
  // fullness is costing anything, which is the question behind opening the panel.
  property real pressure: -1

  function gb(kb) {
    return (kb / 1048576).toFixed(1) + "G";
  }

  function mb(kb) {
    return kb >= 1048576 ? (kb / 1048576).toFixed(1) + "G" : Math.round(kb / 1024) + "M";
  }

  function percent(part, whole) {
    return whole > 0 ? Math.round(part / whole * 100) + "%" : "";
  }

  FileView {
    id: meminfo

    path: "/proc/meminfo"

    onLoaded: {
      var fields = {};
      var lines = text().split("\n");
      for (var i = 0; i < lines.length; i++) {
        var m = lines[i].match(/^(\w+):\s+(\d+)\s+kB/);
        if (m)
          fields[m[1]] = parseInt(m[2], 10);
      }
      if (!fields.MemTotal)
        return;
      root.memTotal = fields.MemTotal;
      root.memAvailable = fields.MemAvailable || 0;
      // SReclaimable is kernel slab that is also handed back under pressure; free(1)
      // counts it as buff/cache and so does this.
      root.cached = (fields.Cached || 0) + (fields.SReclaimable || 0) + (fields.Buffers || 0);
      root.shmem = fields.Shmem || 0;
      root.swapTotal = fields.SwapTotal || 0;
      root.swapFree = fields.SwapFree || 0;
    }
  }

  // mm_stat is a single line of counters; the first three are orig_data_size,
  // compr_data_size and mem_used_total, all in bytes. Absent on a machine that swaps to
  // a real partition, which is why the whole section is conditional.
  FileView {
    id: zramStat

    path: "/sys/block/zram0/mm_stat"
    printErrors: false

    onLoaded: {
      var parts = text().trim().split(/\s+/);
      if (parts.length < 2)
        return;
      root.zramOriginal = parseFloat(parts[0]);
      root.zramCompressed = parseFloat(parts[1]);
    }
    onLoadFailed: {
      root.zramOriginal = 0;
      root.zramCompressed = 0;
    }
  }

  // Summed by command name, not listed per process. Brave alone is a dozen processes,
  // and a list of six of them named "brave" answers nothing -- what you want to know is
  // that the browser is holding four gigabytes.
  Process {
    id: processProbe

    command: ["ps", "-eo", "rss=,comm="]

    function reload() {
      if (!running)
        running = true;
    }

    stdout: StdioCollector {
      onStreamFinished: {
        var totals = {};
        var lines = text.split("\n");
        for (var i = 0; i < lines.length; i++) {
          var m = lines[i].match(/^\s*(\d+)\s+(.+?)\s*$/);
          if (!m)
            continue;
          var name = m[2];
          totals[name] = (totals[name] || 0) + parseInt(m[1], 10);
        }

        var list = [];
        for (var key in totals)
          list.push({
            name: key,
            kb: totals[key]
          });
        list.sort(function (a, b) {
          return b.kb - a.kb;
        });
        root.topProcesses = list.slice(0, 5);
      }
    }
  }

  FileView {
    id: psi

    path: "/proc/pressure/memory"
    printErrors: false
    onLoaded: {
      var m = text().match(/^some avg10=([\d.]+)/m);
      root.pressure = m ? parseFloat(m[1]) : -1;
    }
  }

  function refresh() {
    psi.reload();
    meminfo.reload();
    zramStat.reload();
    processProbe.reload();
  }

  Timer {
    interval: 3000
    repeat: true
    running: root.visible
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  function launch(command) {
    return {
      command: command,
      workingDirectory: Quickshell.env("HOME")
    };
  }

  contentWidth: Style.popupWidth
  contentHeight: column.implicitHeight + Style.popupPadding * 2

  Column {
    id: column

    width: parent.width
    spacing: 2

    // --- How full, big --------------------------------------------------------------------
    PanelHero {
      icon: "\u{f035b}"
      title: "Memory"
      status: {
        if (root.memTotal <= 0)
          return "";
        var parts = [root.gb(root.used) + " of " + root.gb(root.memTotal)];
        if (root.pressure > 1)
          parts.push("under pressure");
        return parts.join("  ·  ");
      }
      statusColor: root.pressure > 10 ? Color.popupUrgent : Color.popupMuted
      value: root.memTotal > 0 ? root.percent(root.used, root.memTotal) : "—"
      valueColor: root.memTotal > 0 && root.used / root.memTotal >= 0.9 ? Color.popupUrgent : Color.popupText
    }

    // The bar carries the point of the whole panel: the solid part is spoken for, the
    // faded part is cache you will get back.
    Item {
      width: parent.width
      height: 18

      PanelMeter {
        anchors.left: parent.left
        anchors.leftMargin: 6
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        value: root.memTotal > 0 ? root.used / root.memTotal : 0
        secondary: root.memTotal > 0 ? root.reclaimable / root.memTotal : 0
      }
    }

    Grid {
      width: parent.width
      columns: 2
      topPadding: 6
      bottomPadding: 4

      PanelStat {
        label: "Used"
        value: root.gb(root.used)
      }
      PanelStat {
        label: "Available"
        value: root.gb(root.memAvailable)
      }
      PanelStat {
        label: "Cache"
        value: root.gb(root.cached)
        muted: true
      }
      PanelStat {
        label: "Pressure"
        value: root.pressure < 0 ? "—" : (root.pressure < 0.1 ? "none" : root.pressure.toFixed(1) + "%")
        warn: root.pressure > 10
      }
      PanelStat {
        label: root.zramActive ? "zram" : "Swap"
        value: root.swapTotal > 0 ? root.mb(root.swapUsed) + " / " + root.gb(root.swapTotal) : "none"
        warn: root.swapTotal > 0 && root.swapUsed > root.swapTotal * 0.5
      }
      // The number that justifies zram existing: swapped pages are held in RAM, so what
      // matters is how much smaller they got, not how many there are.
      PanelStat {
        label: "Compressed"
        value: root.zramActive ? root.zramRatio.toFixed(1) + "×" : "—"
      }
    }

    PanelSection {
      title: "Top consumers"
      value: "by total RSS"
      rule: true
      visible: root.topProcesses.length > 0
    }

    Repeater {
      model: root.topProcesses

      delegate: PanelRow {
        required property var modelData

        icon: "\u{f0234}"
        label: modelData.name
        sublabel: root.percent(modelData.kb, root.memTotal) + " of total"
        enabled: false

        Text {
          text: root.mb(modelData.kb)
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
