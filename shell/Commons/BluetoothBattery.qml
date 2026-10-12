pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import "lowbattery.js" as LowBattery

// The battery of whatever is connected over Bluetooth, and the warning when one runs low.
//
// A singleton because there is a bar per monitor: a warning sent from the widget would
// arrive once for each. It also keeps the widget and the warning on one reading of the
// level. Event-driven off Quickshell's Bluez binding, so nothing polls -- the laptop's
// own battery is watched by a timer (desktop-battery-monitor), but that one only runs
// on machines that have a battery, and a headset can be paired to a desktop.
QtObject {
  id: root

  // The panel turns a device's gauge urgent at the same figure.
  readonly property int threshold: 15

  function level(device) {
    if (!device)
      return -1;
    return LowBattery.percent(device.batteryAvailable, device.battery);
  }

  // Connected devices that report a battery. Read through a binding, never fetched in
  // a handler: the service only starts once something binds to it.
  readonly property var readings: {
    var list = Bluetooth.devices ? Bluetooth.devices.values : [];
    var out = [];
    for (var i = 0; i < list.length; i++) {
      var d = list[i];
      if (!d || !d.connected)
        continue;
      var value = root.level(d);
      if (value >= 0)
        out.push({
          address: d.address,
          name: d.name || d.deviceName || d.address,
          level: value
        });
    }
    return out;
  }

  // The one closest to dying, which is the one the bar has room for. -1 when nothing
  // connected reports a battery.
  readonly property int lowest: {
    var value = -1;
    for (var i = 0; i < readings.length; i++)
      if (value < 0 || readings[i].level < value)
        value = readings[i].level;
    return value;
  }

  // Addresses already warned about. Rebuilt from the readings on every pass, so a
  // device that disconnects drops out of it without anything having to notice it go.
  property var warned: ({})

  function sweep() {
    var next = {};
    for (var i = 0; i < readings.length; i++) {
      var reading = readings[i];
      var result = LowBattery.step(reading.level, warned[reading.address] === true, threshold);
      if (result.warned)
        next[reading.address] = true;
      if (result.notify)
        Quickshell.execDetached(["notify-send", "-a", "Bluetooth", "-i", "battery-caution", "-t", "30000", reading.name + " is running low", "Battery is down to " + reading.level + "%"]);
    }
    warned = next;
  }

  onReadingsChanged: sweep()
  Component.onCompleted: sweep()
}
