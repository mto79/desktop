import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui

// Bluetooth power state and connected device count, polled from bluetoothctl.
//
// Quickshell has no Bluez service, so this parses `bluetoothctl show` and
// `bluetoothctl devices Connected` rather than talking to DBus directly.
BarItem {
  id: root

  property bool powered: false
  property var deviceNames: []

  readonly property int connected: deviceNames.length

  tooltip: {
    if (!powered)
      return "Bluetooth off";
    return connected === 0 ? "Bluetooth on\nNothing connected" : "Bluetooth\n" + deviceNames.join("\n");
  }

  command: ["desktop-launch-bluetooth"]

  IconLabel {
    icon: root.powered ? "" : "󰂲"
    text: root.connected > 0 ? String(root.connected) : ""
    color: root.powered ? Color.barText : Color.barMuted
  }

  Process {
    id: showProbe

    command: ["bluetoothctl", "show"]

    stdout: StdioCollector {
      onStreamFinished: root.powered = /Powered:\s*yes/.test(text)
    }
  }

  Process {
    id: devicesProbe

    command: ["bluetoothctl", "devices", "Connected"]

    stdout: StdioCollector {
      onStreamFinished: {
        // `Device AA:BB:CC:DD:EE:FF Some Speaker` -- everything past the address is
        // the alias, which can itself contain spaces.
        var names = [];
        var lines = text.split("\n");
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].indexOf("Device ") !== 0)
            continue;
          var parts = lines[i].split(" ");
          names.push(parts.slice(2).join(" ") || parts[1]);
        }
        root.deviceNames = names;
      }
    }
  }

  Timer {
    interval: 10000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      if (!showProbe.running)
        showProbe.running = true;
      if (!devicesProbe.running)
        devicesProbe.running = true;
    }
  }
}
