import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Updates panel: what desktop-update would bring in, source by source, and the two
// things to do about it -- run it, or check again.
//
// Same shape as the battery panel: the state big at the top, detail below. Each source
// names what is in it rather than only counting, because "207 packages" is not a reason
// to stop and update, and "a new kernel" or three commits to this desktop might be. A
// source opens on click to list more.
//
// Everything comes from desktop-update-available, which the bar's icon runs as well; a
// check the icon ran in the last minute is reused, so opening the panel costs nothing.
// "Check again" asks for a fresh one, then tells the icon, so the two cannot disagree.
Popup {
  id: root

  readonly property string panelId: "updates"

  property var sources: []
  property real checked: 0
  property bool checking: false
  property string expanded: ""

  // Bumped each minute while open, so "checked 3 min ago" does not freeze at open time.
  property int tick: 0

  readonly property int total: {
    var sum = 0;
    for (var i = 0; i < sources.length; i++)
      sum += sources[i].count;
    return sum;
  }

  readonly property bool newKernel: {
    for (var i = 0; i < sources.length; i++)
      if (sources[i].id === "dnf" && sources[i].items.indexOf("kernel") !== -1)
        return true;
    return false;
  }

  readonly property var icons: ({
      "desktop": "󰊢",
      "dnf": "",
      "firmware": "󰍛",
      "flatpak": "󰏖",
      "cargo": "󱘗"
    })

  // dnf lists alphabetically, which puts PackageKit ahead of the kernel. These go first
  // when present: the ones that change what the machine does after a restart.
  readonly property var notable: ["kernel", "hyprland", "mesa-dri-drivers", "systemd", "glibc", "firefox", "pipewire", "NetworkManager"]

  function preview(source, limit) {
    var items = source.items || [];
    if (source.id === "dnf") {
      var first = notable.filter(function (name) {
        return items.indexOf(name) !== -1;
      });
      items = first.concat(items.filter(function (name) {
        return first.indexOf(name) === -1;
      }));
    }
    return items.slice(0, limit);
  }

  function summary(source) {
    var shown = preview(source, 3);
    var rest = (source.items || []).length - shown.length;
    return shown.join(", ") + (rest > 0 ? "  +" + rest : "");
  }

  function ago(seconds) {
    root.tick;
    if (seconds <= 0)
      return "";
    var minutes = Math.floor((Date.now() / 1000 - seconds) / 60);
    if (minutes < 1)
      return "just now";
    if (minutes < 60)
      return minutes + " min ago";
    return Math.floor(minutes / 60) + " h ago";
  }

  function load(text) {
    try {
      var data = JSON.parse(text);
      root.sources = data.sources || [];
      root.checked = data.checked || 0;
    } catch (e) {
      console.warn("UpdatesPanel: unreadable output from desktop-update-available:", e);
    }
  }

  Process {
    id: probe

    command: ["desktop-update-available", "--json"]

    stdout: StdioCollector {
      onStreamFinished: root.load(text)
    }
  }

  // No --notify: someone looking at the list does not need a toast about it.
  Process {
    id: freshProbe

    command: ["desktop-update-available", "--json", "--fresh"]

    stdout: StdioCollector {
      onStreamFinished: root.load(text)
    }

    onExited: {
      root.checking = false;
      Bus.updatesChanged();
    }
  }

  function checkAgain() {
    if (freshProbe.running)
      return;
    checking = true;
    freshProbe.running = true;
  }

  function update() {
    root.close();
    Quickshell.execDetached({
      command: ["desktop-launch-floating-terminal-with-presentation", "desktop-update"],
      workingDirectory: Quickshell.env("HOME")
    });
  }

  // desktop-update ends by announcing itself on the Bus; an open panel follows.
  Connections {
    target: Bus

    function onUpdatesChanged(): void {
      if (root.visible && !probe.running && !freshProbe.running)
        probe.running = true;
    }
  }

  onVisibleChanged: {
    if (visible && !probe.running)
      probe.running = true;
    if (!visible)
      expanded = "";
  }

  Timer {
    interval: 60000
    repeat: true
    running: root.visible
    onTriggered: root.tick++
  }

  onKeyPressed: event => {
    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      if (root.total > 0)
        root.update();
      event.accepted = true;
    } else if (event.key === Qt.Key_R) {
      root.checkAgain();
      event.accepted = true;
    }
  }

  contentWidth: Style.popupWidth
  contentHeight: column.implicitHeight + Style.popupPadding * 2

  Column {
    id: column

    width: parent.width
    spacing: 2

    // --- How much is waiting ----------------------------------------------------------
    Item {
      width: parent.width
      height: 56

      Text {
        id: heroIcon

        anchors.left: parent.left
        anchors.leftMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        text: root.total > 0 ? "󰚰" : "󰄬"
        color: root.total > 0 ? Color.popupAccent : Color.popupText
        font.family: Style.fontFamily
        font.pixelSize: Style.iconSize * 2.4

        // Turning while a check runs: the one moving thing, and only while it means work.
        RotationAnimation on rotation {
          running: root.checking
          from: 0
          to: 360
          duration: 1200
          loops: Animation.Infinite
          onStopped: heroIcon.rotation = 0
        }
      }

      Column {
        anchors.left: heroIcon.right
        anchors.leftMargin: 12
        anchors.right: heroCount.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Text {
          text: "Updates"
          color: Color.popupText
          font.family: Style.fontFamily
          font.pixelSize: Style.fontSize + 2
          font.bold: true
        }

        Text {
          width: parent.width
          text: {
            if (root.checking)
              return "CHECKING...";
            if (root.total === 0)
              return "UP TO DATE";
            return root.newKernel ? "NEW KERNEL  ·  RESTART AFTER" : "READY TO INSTALL";
          }
          color: root.checking || root.newKernel ? Color.popupAccent : Color.popupMuted
          font.family: Style.fontFamily
          font.pixelSize: Style.fontSize - 2
          font.bold: true
          font.letterSpacing: 1
          elide: Text.ElideRight
        }
      }

      Text {
        id: heroCount

        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        text: root.total > 0 ? String(root.total) : "0"
        color: root.total > 0 ? Color.popupText : Color.popupMuted
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSize * 2.2
        font.bold: true
      }
    }

    // --- Source by source -------------------------------------------------------------
    PanelSection {
      title: "Waiting"
      value: "click to list"
      rule: true
      visible: root.sources.length > 0
    }

    Repeater {
      model: root.sources

      delegate: Column {
        id: source

        required property var modelData

        readonly property bool open: root.expanded === modelData.id

        width: column.width

        PanelRow {
          icon: root.icons[source.modelData.id] || "󰏗"
          label: source.modelData.count + " " + source.modelData.label
          sublabel: root.summary(source.modelData)
          active: source.open
          onClicked: root.expanded = source.open ? "" : source.modelData.id

          Text {
            text: source.open ? "󰅃" : "󰅀"
            color: Color.popupMuted
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSize
          }
        }

        // Up to a dozen, in two columns: enough to spot the one you care about, without
        // the panel growing a scrollbar for 207 package names.
        Grid {
          visible: source.open
          width: parent.width
          columns: 2
          leftPadding: 36
          rightPadding: 6
          topPadding: 2
          bottomPadding: 6
          columnSpacing: 10

          Repeater {
            model: source.open ? root.preview(source.modelData, 12) : []

            delegate: Text {
              required property string modelData

              width: (source.width - 36 - 6 - 10) / 2
              text: modelData
              color: Color.popupText
              font.family: Style.fontFamily
              font.pixelSize: Style.fontSize - 2
              elide: Text.ElideRight
            }
          }
        }

        Text {
          visible: source.open && source.modelData.items.length > 12
          leftPadding: 36
          bottomPadding: 6
          text: "and " + (source.modelData.items.length - 12) + " more"
          color: Color.popupMuted
          font.family: Style.fontFamily
          font.pixelSize: Style.fontSize - 2
        }
      }
    }

    // --- What to do about it ----------------------------------------------------------
    PanelSection {
      title: "Actions"
      value: root.total > 0 ? "enter  ·  r" : "r"
      rule: true
    }

    PanelRow {
      visible: root.total > 0
      icon: "󰚰"
      label: "Update now"
      sublabel: "Runs desktop-update in a terminal"
      active: true
      onClicked: root.update()
    }

    PanelRow {
      icon: "󰑐"
      label: root.checking ? "Checking..." : "Check again"
      sublabel: root.checked > 0 ? "Last checked " + root.ago(root.checked) : "Not checked yet"
      enabled: !root.checking
      onClicked: root.checkAgain()
    }
  }
}
