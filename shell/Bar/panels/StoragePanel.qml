import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Storage panel: how full the system disk is, what is filling it, and the other drives.
//
// Same shape as the battery panel: the level big at the top, a gauge, the numbers in a
// grid. Below that, the folders that grow without anyone deciding they should --
// downloads, trash, caches, containers, Flatpak -- because "72% used" is only useful next
// to where the space went. Measuring those takes minutes over container storage, so
// they arrive one by one, and are kept for an hour.
//
// /boot sits in the grid on its own line: it is a small partition that fills with kernels,
// and a full one is how a Fedora update fails halfway. It turns red well before that.
Popup {
  id: root

  readonly property string panelId: "storage"

  property var filesystems: []
  property var snapshots: null
  property var usage: []
  property bool measuring: false

  // The trash is emptied on the second click, within a few seconds of the first.
  property bool confirmEmpty: false

  readonly property var system: {
    for (var i = 0; i < filesystems.length; i++)
      if (filesystems[i].mount === "/")
        return filesystems[i];
    return filesystems.length > 0 ? filesystems[0] : null;
  }

  readonly property var boot: {
    for (var i = 0; i < filesystems.length; i++)
      if (filesystems[i].mount === "/boot")
        return filesystems[i];
    return null;
  }

  // Everything but the system volume and the two boot partitions.
  readonly property var others: filesystems.filter(function (fs) {
    return fs !== root.system && fs.mount !== "/boot" && fs.mount !== "/boot/efi";
  })

  readonly property int usedPercent: system && system.size > 0 ? Math.round(system.used / system.size * 100) : 0
  readonly property int bootPercent: boot && boot.size > 0 ? Math.round(boot.used / boot.size * 100) : 0

  readonly property var usageIcons: ({
      "downloads": "󰉍",
      "trash": "󰩹",
      "cache": "󰃨",
      "flatpak": "󰏖",
      "containers": "󰡨"
    })

  // Decimal units, as drives are sold and as df -H prints them.
  function bytes(value) {
    var units = ["B", "KB", "MB", "GB", "TB"];
    var unit = 0;
    while (value >= 1000 && unit < units.length - 1) {
      value /= 1000;
      unit++;
    }
    return (unit === 0 || value >= 100 ? Math.round(value) : value.toFixed(1)) + " " + units[unit];
  }

  function driveName(fs) {
    if (!fs)
      return "";
    return fs.model ? fs.model.replace(/^\S+ NVMe /, "").trim() : fs.device;
  }

  function launch(command) {
    Quickshell.execDetached({
      command: command,
      workingDirectory: Quickshell.env("HOME")
    });
  }

  Process {
    id: detailsProbe

    command: ["desktop-storage-details"]

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var data = JSON.parse(text);
          root.filesystems = data.filesystems || [];
          root.snapshots = data.snapshots;
        } catch (e) {}
      }
    }
  }

  // One line per folder as it is measured; a line replaces any earlier one for its id.
  Process {
    id: usageProbe

    command: ["desktop-storage-details", "--usage"]

    stdout: SplitParser {
      onRead: line => {
        try {
          var entry = JSON.parse(line);
          var next = root.usage.filter(function (u) {
            return u.id !== entry.id;
          });
          next.push(entry);
          next.sort(function (a, b) {
            return b.bytes - a.bytes;
          });
          root.usage = next;
        } catch (e) {}
      }
    }

    onExited: root.measuring = false
  }

  Process {
    id: emptier

    command: ["gio", "trash", "--empty"]

    onExited: {
      // The trash is measured again; the hour-long cache would otherwise keep its size.
      root.usage = root.usage.map(function (u) {
        return u.id === "trash" ? Object.assign({}, u, {
          bytes: 0
        }) : u;
      });
      detailsProbe.running = true;
    }
  }

  Timer {
    id: confirmTimer

    interval: 4000
    onTriggered: root.confirmEmpty = false
  }

  function emptyTrash() {
    if (!confirmEmpty) {
      confirmEmpty = true;
      confirmTimer.restart();
      return;
    }
    confirmEmpty = false;
    if (!emptier.running)
      emptier.running = true;
  }

  // Unmount, then power the drive down, so it can be pulled without the kernel noticing
  // mid-write. udisks does both without root for a drive the session owns.
  function eject(fs) {
    launch(["bash", "-c", "udisksctl unmount -b \"$1\" && { [ -z \"$2\" ] || udisksctl power-off -b \"$2\"; }", "eject", fs.device, fs.disk || ""]);
    ejectRefresh.restart();
  }

  Timer {
    id: ejectRefresh

    interval: 1500
    onTriggered: detailsProbe.running = true
  }

  onVisibleChanged: {
    if (visible) {
      if (!detailsProbe.running)
        detailsProbe.running = true;
      if (!usageProbe.running) {
        measuring = true;
        usageProbe.running = true;
      }
    } else {
      confirmEmpty = false;
    }
  }

  contentWidth: Style.popupWidth
  contentHeight: column.implicitHeight + Style.popupPadding * 2

  Column {
    id: column

    width: parent.width
    spacing: 2

    // --- How full, big -----------------------------------------------------------------
    PanelHero {
      icon: "󰋊"
      title: root.system ? root.driveName(root.system) : "Storage"
      status: {
        if (!root.system)
          return "";
        var parts = [root.bytes(root.system.avail) + " free"];
        if (root.system.encrypted)
          parts.push("encrypted");
        return parts.join("  ·  ");
      }
      value: root.system ? root.usedPercent + "%" : "—"
      valueColor: root.usedPercent >= 90 ? Color.popupUrgent : Color.popupText
    }

    Item {
      width: parent.width
      height: 18

      PanelMeter {
        anchors.left: parent.left
        anchors.leftMargin: 6
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        value: root.usedPercent / 100
        fillColor: root.usedPercent >= 90 ? Color.popupUrgent : Color.popupAccent
      }
    }

    Grid {
      width: parent.width
      columns: 2
      topPadding: 6
      bottomPadding: 4
      visible: !!root.system

      PanelStat {
        label: "Used"
        value: root.system ? root.bytes(root.system.used) : "—"
      }
      PanelStat {
        label: "Size"
        value: root.system ? root.bytes(root.system.size) : "—"
      }
      PanelStat {
        label: "Filesystem"
        value: root.system ? root.system.fstype : "—"
      }
      PanelStat {
        label: "Snapshots"
        value: root.snapshots !== null && root.snapshots !== undefined ? String(root.snapshots) : "—"
      }
      PanelStat {
        label: "/boot"
        value: root.boot ? root.bootPercent + "% full" : "—"
        warn: root.bootPercent >= 80
      }
      PanelStat {
        label: "Boot free"
        value: root.boot ? root.bytes(root.boot.avail) : "—"
        warn: root.bootPercent >= 80
      }
    }

    // --- Where it went -----------------------------------------------------------------
    PanelSection {
      title: "Where it goes"
      value: root.measuring ? "measuring..." : "click to open"
      rule: true
    }

    Repeater {
      model: root.usage

      delegate: PanelRow {
        required property var modelData

        readonly property bool isTrash: modelData.id === "trash"

        icon: root.usageIcons[modelData.id] || "󰉋"
        label: modelData.label
        sublabel: {
          if (isTrash && root.confirmEmpty)
            return "Right-click again to empty it for good";
          if (isTrash && modelData.bytes > 0)
            return "Right-click to empty";
          return modelData.path.replace(Quickshell.env("HOME"), "~");
        }
        active: isTrash && root.confirmEmpty
        onClicked: {
          root.close();
          root.launch(["desktop-launch-files", modelData.path]);
        }
        onRightClicked: if (isTrash && modelData.bytes > 0)
          root.emptyTrash()

        Text {
          text: root.bytes(modelData.bytes)
          color: Color.popupText
          font.family: Style.fontFamily
          font.pixelSize: Style.fontSize - 1
        }
      }
    }

    Item {
      width: parent.width
      height: visible ? 22 : 0
      visible: root.usage.length === 0

      Text {
        anchors.left: parent.left
        anchors.leftMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        text: "Measuring folders, at idle priority..."
        color: Color.popupMuted
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSize - 2
      }
    }

    // --- Everything else mounted ------------------------------------------------------
    PanelSection {
      title: "Other drives"
      rule: true
      visible: root.others.length > 0
    }

    Repeater {
      model: root.others

      delegate: PanelRow {
        required property var modelData

        icon: modelData.removable ? "󰕓" : "󰋊"
        label: modelData.mount
        sublabel: root.bytes(modelData.avail) + " free of " + root.bytes(modelData.size) + "  ·  " + modelData.fstype + (modelData.removable ? "  ·  right-click to eject" : "")
        onClicked: {
          root.close();
          root.launch(["desktop-launch-files", modelData.mount]);
        }
        onRightClicked: if (modelData.removable)
          root.eject(modelData)
      }
    }

    PanelSection {
      title: "Advanced"
      rule: true
    }

    PanelRow {
      icon: "󰨸"
      label: "Analyze disk usage"
      sublabel: "Every folder, largest first"
      onClicked: {
        root.close();
        root.launch(["desktop-launch-disk", "/"]);
      }
    }
  }
}
