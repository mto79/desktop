import QtQuick
import Quickshell.Bluetooth
import qs.Commons
import qs.Ui

// Bluetooth power state and connected devices.
//
// Reads Quickshell's Bluez binding rather than polling bluetoothctl every ten seconds,
// so the icon changes the moment a headset connects instead of up to ten seconds later
// -- and the widget and its panel cannot disagree about what is connected. The service
// only starts once something binds to it, which every property below does.
BarItem {
  id: root

  readonly property var adapter: Bluetooth.defaultAdapter
  readonly property bool powered: adapter ? adapter.enabled : false

  readonly property var connectedDevices: {
    var list = Bluetooth.devices ? Bluetooth.devices.values : [];
    var out = [];
    for (var i = 0; i < list.length; i++)
      if (list[i] && list[i].connected)
        out.push(list[i]);
    return out;
  }

  readonly property int connected: connectedDevices.length

  tooltip: {
    if (!adapter)
      return "No Bluetooth adapter";
    if (!powered)
      return "Bluetooth off";
    if (connected === 0)
      return "Bluetooth on\nNothing connected";
    var names = [];
    for (var i = 0; i < connectedDevices.length; i++) {
      var d = connectedDevices[i];
      names.push(d.name || d.deviceName || d.address);
    }
    return "Bluetooth\n" + names.join("\n");
  }

  // Left click opens the panel; right click keeps bluetui one gesture away, since
  // pairing a device that wants a passkey confirmation still needs its agent.
  panelId: "bluetooth"

  onClicked: if (popups)
    popups.toggle(root.panelId, this)
  rightCommand: ["desktop-launch-bluetooth"]

  IconLabel {
    icon: root.powered ? "\u{f294}" : "\u{f00b2}"
    text: root.connected > 0 ? String(root.connected) : ""
    color: root.powered ? Color.barText : Color.barMuted
  }
}
