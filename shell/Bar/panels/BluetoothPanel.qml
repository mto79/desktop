import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs.Commons
import qs.Ui

// Bluetooth panel: adapter power, paired devices, and whatever is in range.
//
// Quickshell grew a Bluez binding, so none of this shells out to bluetoothctl the way
// the bar widget used to. Two consequences worth knowing:
//
//   * The service starts when something binds to it, so every read here goes through a
//     declarative property rather than being fetched inside a handler -- the same rule
//     NetworkPanel documents for Networking.
//   * Discovery is adapter-global and writable, so it runs only while the panel is
//     open. A bar sitting closed is not holding the radio in scan.
//
// Laid out like the battery panel: the state big at the top, then each connected device
// as a card with its battery as a gauge -- the headset about to die is the thing worth
// seeing at a glance -- and the list of everything else below.
//
// bluetui stays one gesture away under Advanced. Pairing a device that wants a
// passkey confirmation still needs an agent, and this panel does not implement one.
Popup {
  id: root

  readonly property string panelId: "bluetooth"

  readonly property var adapter: Bluetooth.defaultAdapter
  readonly property bool powered: adapter ? adapter.enabled : false
  readonly property bool blocked: adapter ? adapter.state === BluetoothAdapterState.Blocked : false

  // Keyboard state, as in NetworkPanel: typing filters, arrows move a cursor.
  property string filter: ""
  property int cursor: -1

  readonly property var liveDevices: Bluetooth.devices ? Bluetooth.devices.values : []

  // Debounced snapshot. A running scan churns the model every few seconds, and a
  // Repeater rebuilt from inside the model's own change signal is a crash waiting to
  // happen -- the same reason AudioPanel and NetworkPanel each keep one.
  property var devices: []

  function rebuild() {
    var list = [];
    for (var i = 0; i < liveDevices.length; i++) {
      var d = liveDevices[i];
      if (!d)
        continue;
      // Unnamed devices are MAC addresses in a list you cannot act on: bluez reports
      // every beacon and laptop in the room during a scan.
      if (!d.name && !d.deviceName)
        continue;
      list.push(d);
    }

    // Connected first, then paired, then the rest by name. Keeps the rows you are
    // likely to want from moving around underneath you as the scan updates.
    list.sort(function (a, b) {
      if (a.connected !== b.connected)
        return a.connected ? -1 : 1;
      if (a.paired !== b.paired)
        return a.paired ? -1 : 1;
      return root.deviceName(a).localeCompare(root.deviceName(b));
    });
    devices = list;
  }

  Timer {
    id: rebuildTimer

    interval: 75
    repeat: false
    onTriggered: root.rebuild()
  }

  onLiveDevicesChanged: rebuildTimer.restart()

  // Scan only while the panel is open. `when` matters: without it the binding would
  // leave the adapter discovering after the panel closes.
  Binding {
    target: root.adapter
    property: "discovering"
    value: root.visible && root.powered
    when: root.adapter !== null
  }

  onVisibleChanged: {
    if (visible) {
      root.rebuild();
    } else {
      root.filter = "";
      root.cursor = -1;
    }
  }

  function deviceName(device) {
    if (!device)
      return "";
    return device.name || device.deviceName || device.address || "";
  }

  readonly property var connectedDevices: devices.filter(function (d) {
    return d.connected;
  })

  // The list below the cards: everything not already shown as one.
  readonly property var visibleDevices: {
    var needle = filter.toLowerCase();
    var out = [];
    for (var i = 0; i < devices.length; i++) {
      if (devices[i].connected)
        continue;
      if (needle === "" || deviceName(devices[i]).toLowerCase().indexOf(needle) !== -1)
        out.push(devices[i]);
    }
    return out;
  }

  function batteryLevel(device) {
    if (!device || !device.batteryAvailable)
      return -1;
    var value = device.battery;
    return value <= 1 ? value : value / 100;
  }

  function moveCursor(delta) {
    var count = visibleDevices.length;
    if (count === 0) {
      cursor = -1;
      return;
    }
    cursor = cursor < 0 ? (delta > 0 ? 0 : count - 1) : (cursor + delta + count) % count;
    ensureCursorVisible();
  }

  // Rows differ in height -- a sublabel makes one taller -- so ask the row where it is
  // rather than multiplying an assumed row height.
  function ensureCursorVisible() {
    if (cursor < 0 || cursor >= deviceColumn.children.length)
      return;
    var row = deviceColumn.children[cursor];
    if (!row)
      return;
    if (row.y < deviceList.contentY)
      deviceList.contentY = row.y;
    else if (row.y + row.height > deviceList.contentY + deviceList.height)
      deviceList.contentY = row.y + row.height - deviceList.height;
  }

  onKeyPressed: event => {
    if (event.key === Qt.Key_Down) {
      root.moveCursor(1);
      event.accepted = true;
    } else if (event.key === Qt.Key_Up) {
      root.moveCursor(-1);
      event.accepted = true;
    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      if (root.cursor >= 0 && root.cursor < root.visibleDevices.length)
        root.activate(root.visibleDevices[root.cursor]);
      event.accepted = true;
    } else if (event.key === Qt.Key_Backspace) {
      root.filter = root.filter.slice(0, -1);
      root.cursor = -1;
      event.accepted = true;
    } else if (event.key === Qt.Key_Escape && root.filter !== "") {
      root.filter = "";
      root.cursor = -1;
      event.accepted = true;
    } else if (event.text !== "" && event.text >= " ") {
      root.filter += event.text;
      root.cursor = -1;
      event.accepted = true;
    }
  }

  // bluez reports a freedesktop icon name; map the ones that actually turn up on a
  // desk to glyphs, and fall back to the bluetooth mark for everything else.
  function deviceIcon(device) {
    if (!device)
      return "\u{f00af}";
    switch (device.icon) {
    case "audio-headphones":
      return "\u{f02cb}";
    case "audio-headset":
      return "\u{f02ce}";
    case "audio-card":
    case "audio-speakers":
      return "\u{f04c3}";
    case "input-mouse":
      return "\u{f037d}";
    case "input-keyboard":
      return "\u{f030c}";
    case "phone":
      return "\u{f011c}";
    case "computer":
      return "\u{f0322}";
    case "watch":
      return "\u{f0b3a}";
    default:
      return "\u{f00af}";
    }
  }

  // bluez publishes battery as a percentage, but Quickshell's other percentages are
  // fractions, so accept either rather than showing "0%" on a full headset.
  function batteryText(device) {
    if (!device || !device.batteryAvailable)
      return "";
    var value = device.battery;
    if (value <= 1)
      value = value * 100;
    return Math.round(value) + "%";
  }

  function stateLabel(device) {
    if (!device)
      return "";
    if (device.pairing)
      return "pairing...";
    if (device.state === BluetoothDeviceState.Connecting)
      return "connecting...";
    if (device.state === BluetoothDeviceState.Disconnecting)
      return "disconnecting...";
    if (device.connected)
      return "connected";
    if (device.paired || device.bonded)
      return "paired";
    return "in range";
  }

  // Pairing happens implicitly: bluez pairs on first connect for devices that need no
  // passkey, which covers headsets, mice and keyboards on this desk. Anything that
  // wants a confirmation dialog needs an agent, and that is what bluetui is for.
  function activate(device) {
    if (!device)
      return;
    if (device.connected) {
      device.disconnect();
      return;
    }
    if (!device.paired && !device.bonded)
      device.pair();
    else
      device.connect();
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

    // --- On or off, and how much is connected, big ---------------------------------------
    PanelHero {
      icon: root.powered ? "\u{f00af}" : "\u{f00b2}"
      iconColor: root.powered ? Color.popupText : Color.popupMuted
      title: "Bluetooth"
      status: {
        if (!root.adapter)
          return "NO ADAPTER";
        if (root.blocked)
          return "BLOCKED IN HARDWARE";
        if (!root.powered)
          return "OFF";
        var parts = ["on"];
        if (root.adapter.discovering)
          parts.push("scanning");
        return parts.join("  ·  ");
      }
      statusColor: root.powered ? Color.popupMuted : (root.blocked ? Color.popupUrgent : Color.popupMuted)
      value: root.powered ? String(root.connectedDevices.length) : "—"
      valueColor: root.connectedDevices.length > 0 ? Color.popupText : Color.popupMuted
    }

    PanelRow {
      icon: root.powered ? "\u{f294}" : "\u{f00b2}"
      label: root.powered ? "Bluetooth on" : "Bluetooth off"
      sublabel: {
        if (!root.adapter)
          return "no adapter found";
        if (root.blocked)
          return "blocked in hardware";
        return "click to turn " + (root.powered ? "off" : "on");
      }
      enabled: !!root.adapter && !root.blocked
      active: root.powered
      onClicked: if (root.adapter)
        root.adapter.enabled = !root.adapter.enabled
    }

    // --- Connected: a card each, battery as a gauge ------------------------------------
    PanelSection {
      title: "Connected"
      value: "click to disconnect"
      rule: true
      visible: root.connectedDevices.length > 0
    }

    Repeater {
      model: root.connectedDevices

      delegate: Rectangle {
        id: card

        required property var modelData

        readonly property real level: root.batteryLevel(modelData)

        width: column.width
        height: 58
        radius: Style.radius
        color: cardArea.containsMouse ? Color.popupHover : Color.popupSelected
        border.width: 1
        border.color: Color.popupBorder

        Text {
          id: cardIcon

          anchors.left: parent.left
          anchors.leftMargin: 12
          anchors.verticalCenter: parent.verticalCenter
          text: root.deviceIcon(card.modelData)
          color: Color.popupAccent
          font.family: Style.fontFamily
          font.pixelSize: Style.iconSize + 8
        }

        Column {
          anchors.left: cardIcon.right
          anchors.leftMargin: 12
          anchors.right: parent.right
          anchors.rightMargin: 12
          anchors.verticalCenter: parent.verticalCenter
          spacing: 5

          Item {
            width: parent.width
            height: nameText.implicitHeight

            Text {
              id: nameText

              anchors.left: parent.left
              anchors.right: levelText.left
              anchors.rightMargin: 8
              text: root.deviceName(card.modelData)
              color: Color.popupText
              font.family: Style.fontFamily
              font.pixelSize: Style.fontSize
              font.bold: true
              elide: Text.ElideRight
            }

            Text {
              id: levelText

              anchors.right: parent.right
              text: card.level >= 0 ? Math.round(card.level * 100) + "%" : root.stateLabel(card.modelData)
              color: card.level >= 0 && card.level <= 0.15 ? Color.popupUrgent : Color.popupMuted
              font.family: Style.fontFamily
              font.pixelSize: Style.fontSize - 1
            }
          }

          // Only for devices that report a battery; a mouse on a cable has nothing to say.
          PanelMeter {
            width: parent.width
            visible: card.level >= 0
            value: card.level
            fillColor: card.level <= 0.15 ? Color.popupUrgent : Color.popupAccent
          }
        }

        MouseArea {
          id: cardArea

          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.activate(card.modelData)
        }
      }
    }

    PanelSection {
      title: "Devices"
      value: root.filter !== "" ? "filter: " + root.filter : (root.adapter && root.adapter.discovering ? "scanning..." : "")
      rule: true
      visible: root.powered
    }

    // Six rows then scroll, as in NetworkPanel: a scan in an office finds plenty, and
    // the panel is not allowed to grow into a full-screen list.
    Flickable {
      id: deviceList

      width: parent.width
      height: Math.min(contentHeight, Style.rowHeight * 6)
      contentHeight: deviceColumn.implicitHeight
      visible: root.powered && root.visibleDevices.length > 0
      clip: true
      boundsBehavior: Flickable.StopAtBounds

      Column {
        id: deviceColumn

        width: deviceList.width

        Repeater {
          model: root.visibleDevices

          delegate: PanelRow {
            required property var modelData
            required property int index

            cursor: root.cursor === index
            icon: root.deviceIcon(modelData)
            label: root.deviceName(modelData)
            sublabel: root.stateLabel(modelData)
            active: modelData ? modelData.connected : false

            onClicked: root.activate(modelData)
            // Forgetting is destructive and easy to hit by accident in a list this
            // long, so it stays on the right button -- as it does for saved Wi-Fi.
            onRightClicked: if (modelData && (modelData.paired || modelData.bonded))
              modelData.forget()

            Text {
              text: root.batteryText(modelData)
              color: Color.popupMuted
              font.family: Style.fontFamily
              font.pixelSize: Style.fontSize - 2
            }
          }
        }
      }
    }

    // An empty list while powered reads as a broken panel otherwise -- there is no row
    // to explain that the scan simply has not found anything yet.
    Item {
      width: parent.width
      height: visible ? 22 : 0
      visible: root.powered && root.visibleDevices.length === 0

      Text {
        anchors.left: parent.left
        anchors.leftMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        text: root.filter !== "" ? "No device matches " + root.filter : "Scanning for devices..."
        color: Color.popupMuted
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSize - 2
        elide: Text.ElideRight
      }
    }

    PanelSection {
      title: "Advanced"
      rule: true
    }

    PanelRow {
      icon: "\u{f294}"
      label: "Open bluetui"
      sublabel: "Pairing that needs a passkey"
      onClicked: {
        root.close();
        Quickshell.execDetached(root.launch(["desktop-launch-bluetooth"]));
      }
    }
  }
}
