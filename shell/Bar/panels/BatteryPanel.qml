import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.Commons
import qs.Ui

// Battery panel: the level at a glance, what the battery is doing and for how long, how
// worn it is, and the power profile -- the one setting worth changing from here.
//
// After Omarchy's power panel, without its rotating status phrases: a line that changes
// every three seconds is one you cannot read at a glance, which is what it is for.
//
// Level, state and time remaining come from UPower, which smooths them; watts, wear,
// cycles and the charge limit from desktop-battery-details, which reads the kernel. The
// status says "holding" rather than "charging" when the battery is plugged in and not
// taking charge -- sitting at a limit -- because "charging at 0 W" reads like a fault.
Popup {
  id: root

  readonly property string panelId: "battery"

  readonly property var device: UPower.displayDevice
  readonly property bool present: device !== null && device.isPresent
  readonly property int percent: device ? Math.round((device.percentage || 0) * 100) : 0
  readonly property bool onBattery: present && UPower.onBattery

  property var info: ({})

  readonly property bool charging: present && !onBattery && info.status === "Charging"
  // Plugged in and not taking charge: at a limit, or full.
  readonly property bool holding: present && !onBattery && !charging

  readonly property string status: {
    if (!present)
      return "";
    if (onBattery)
      return "On battery";
    if (charging)
      return "Charging";
    return percent >= 99 ? "Fully charged" : "Holding at " + percent + "%";
  }

  // A limit is only worth stating when the firmware honours it. Dell keeps thresholds
  // whatever the mode but applies them only in Custom; drivers without modes (ThinkPads)
  // always apply theirs.
  readonly property bool limitApplies: info.limit_end !== undefined && info.limit_end !== null && info.limit_end < 100 && (!info.mode || info.mode === "Custom")

  property var profiles: []
  property string activeProfile: ""

  readonly property var dischargingIcons: ["󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]
  readonly property var chargingIcons: ["󰢜", "󰂆", "󰂇", "󰂈", "󰢝", "󰂉", "󰢞", "󰂊", "󰂋", "󰂅"]

  readonly property string icon: {
    var ramp = charging ? chargingIcons : dischargingIcons;
    return ramp[Math.min(9, Math.max(0, Math.floor(percent / 10)))];
  }

  function duration(seconds) {
    if (!seconds || seconds <= 0)
      return "";
    var hours = Math.floor(seconds / 3600);
    var minutes = Math.round((seconds % 3600) / 60);
    return hours > 0 ? hours + "h " + minutes + "m" : minutes + "m";
  }

  // UPower reports a time to empty while plugged in -- 251 days, at a trickle -- so it is
  // only asked for the one that applies.
  readonly property string remaining: {
    if (!present)
      return "";
    if (onBattery)
      return duration(device.timeToEmpty);
    if (charging)
      return duration(device.timeToFull);
    return "";
  }

  readonly property var profileIcons: ({
      "power-saver": "󰌪",
      "balanced": "󰊚",
      "performance": "󰓅"
    })

  function profileLabel(name) {
    return name === "power-saver" ? "Saver" : name.charAt(0).toUpperCase() + name.slice(1);
  }

  Process {
    id: infoProbe

    command: ["desktop-battery-details"]

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          root.info = JSON.parse(text);
        } catch (e) {}
      }
    }
  }

  // desktop-powerprofiles-list prints saver first, performance last: the order the
  // buttons read in, slowest to fastest.
  Process {
    id: profileProbe

    command: ["bash", "-c", "desktop-powerprofiles-list; echo; powerprofilesctl get"]

    stdout: StdioCollector {
      onStreamFinished: {
        var parts = text.trim().split("\n\n");
        var list = parts[0] ? parts[0].split("\n").filter(function (s) {
          return s !== "";
        }) : [];
        if (list.length > 0)
          root.profiles = list;
        root.activeProfile = parts.length > 1 ? parts[1].trim() : "";
      }
    }
  }

  // No notification, unlike desktop-powerprofiles-set: the button that lights up is
  // the confirmation.
  Process {
    id: profileSet

    onExited: profileProbe.running = true
  }

  function setProfile(name) {
    if (!name || name === activeProfile || profileSet.running)
      return;
    activeProfile = name;
    profileSet.command = ["powerprofilesctl", "set", name];
    profileSet.running = true;
  }

  function stepProfile(delta) {
    var index = profiles.indexOf(activeProfile);
    var next = Math.max(0, Math.min(profiles.length - 1, index + delta));
    if (profiles.length > 0)
      setProfile(profiles[next]);
  }

  function refresh() {
    if (!infoProbe.running)
      infoProbe.running = true;
    if (!profileProbe.running)
      profileProbe.running = true;
  }

  Timer {
    interval: 5000
    repeat: true
    running: root.visible
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  onKeyPressed: event => {
    if (event.key === Qt.Key_Left) {
      root.stepProfile(-1);
      event.accepted = true;
    } else if (event.key === Qt.Key_Right) {
      root.stepProfile(1);
      event.accepted = true;
    }
  }

  contentWidth: Style.popupWidth
  contentHeight: column.implicitHeight + Style.popupPadding * 2

  Column {
    id: column

    width: parent.width
    spacing: 2

    // --- The level, big enough to read from across the desk --------------------------
    PanelHero {
      icon: root.icon
      title: "Battery"
      status: root.status
      statusColor: root.charging ? Color.popupAccent : Color.popupMuted
      value: root.present ? root.percent + "%" : "—"
      valueColor: root.onBattery && root.percent <= 10 ? Color.popupUrgent : Color.popupText
    }

    Item {
      width: parent.width
      height: 18

      PanelMeter {
        id: meter

        anchors.left: parent.left
        anchors.leftMargin: 6
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        value: root.percent / 100
        fillColor: root.onBattery && root.percent <= 10 ? Color.popupUrgent : (root.onBattery && root.percent <= 20 ? Color.barAccent : Color.popupAccent)

        // Breathes while charge is flowing in, and only then -- the one moving thing in
        // the panel, so it means something.
        SequentialAnimation on opacity {
          running: root.charging && root.visible
          loops: Animation.Infinite
          alwaysRunToEnd: true

          NumberAnimation {
            to: 0.55
            duration: 950
            easing.type: Easing.InOutSine
          }
          NumberAnimation {
            to: 1.0
            duration: 950
            easing.type: Easing.InOutSine
          }
        }
      }
    }

    // --- The numbers ------------------------------------------------------------------
    Grid {
      width: parent.width
      columns: 2
      topPadding: 6
      bottomPadding: 4

      // Holding, there is no time to count down and no rate worth quoting -- "charging at
      // 0 W" reads like a fault -- so the row says where the power comes from instead.
      PanelStat {
        label: root.holding ? "Power" : (root.onBattery ? "Time left" : "Time to full")
        value: root.holding ? "AC" : (root.remaining !== "" ? root.remaining : "—")
      }
      PanelStat {
        label: root.holding ? "Battery" : (root.onBattery ? "Drawing" : "Charging at")
        value: {
          if (root.holding)
            return "idle";
          return root.info.watts !== undefined && root.info.watts !== null ? root.info.watts + " W" : "—";
        }
      }
      PanelStat {
        label: "Health"
        value: root.info.health ? root.info.health + "%" : "—"
      }
      PanelStat {
        label: "Capacity"
        value: root.info.full_wh ? root.info.full_wh + " Wh" : "—"
      }
      PanelStat {
        label: "Cycles"
        value: root.info.cycles ? String(root.info.cycles) : "—"
      }
      PanelStat {
        label: root.limitApplies ? "Limit" : "Mode"
        value: {
          if (root.limitApplies)
            return (root.info.limit_start ? root.info.limit_start + "–" : "") + root.info.limit_end + "%";
          return root.info.mode || "—";
        }
      }
    }

    // --- Power profile ----------------------------------------------------------------
    PanelSection {
      title: "Power profile"
      value: "← →"
      rule: true
      visible: root.profiles.length > 0
    }

    Row {
      id: profileRow

      width: parent.width
      spacing: 6
      leftPadding: 6
      rightPadding: 6
      topPadding: 2
      visible: root.profiles.length > 0

      readonly property real cellWidth: (width - leftPadding - rightPadding - spacing * (root.profiles.length - 1)) / Math.max(1, root.profiles.length)

      Repeater {
        model: root.profiles

        delegate: Rectangle {
          id: cell

          required property string modelData

          readonly property bool active: root.activeProfile === modelData

          width: profileRow.cellWidth
          height: 54
          radius: Style.radius
          color: active ? Color.popupSelected : (area.containsMouse ? Color.popupHover : "transparent")
          border.width: 1
          border.color: active ? Color.popupAccent : Color.popupBorder

          Column {
            anchors.centerIn: parent
            spacing: 3

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: root.profileIcons[cell.modelData] || "󰂄"
              color: cell.active ? Color.popupAccent : Color.popupText
              font.family: Style.fontFamily
              font.pixelSize: Style.iconSize + 3
            }

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: root.profileLabel(cell.modelData)
              color: cell.active ? Color.popupAccent : Color.popupMuted
              font.family: Style.fontFamily
              font.pixelSize: Style.fontSize - 2
            }
          }

          MouseArea {
            id: area

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.setProfile(cell.modelData)
          }
        }
      }
    }
  }
}
