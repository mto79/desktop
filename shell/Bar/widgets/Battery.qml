import QtQuick
import Quickshell.Services.UPower
import qs.Commons
import qs.Ui

// Battery level from UPower's display device, which is the aggregate UPower already
// computes -- no need to pick a BAT0 ourselves.
BarItem {
  id: root

  // The display device is UPower's own aggregate, so there is no BAT0 to pick. On a
  // desktop it reports isPresent false, which hides the widget.
  readonly property var device: UPower.displayDevice
  readonly property bool present: device !== null && device.isPresent
  readonly property int percent: device ? Math.round((device.percentage || 0) * 100) : 0
  readonly property bool discharging: present && UPower.onBattery && device.state === UPowerDeviceState.Discharging
  readonly property bool charging: present && !discharging

  // Nerd-font ramps, carried over from the waybar config so the bar looks unchanged.
  readonly property var dischargingIcons: ["󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]
  readonly property var chargingIcons: ["󰢜", "󰂆", "󰂇", "󰂈", "󰢝", "󰂉", "󰢞", "󰂊", "󰂋", "󰂅"]

  readonly property string icon: {
    var ramp = charging ? chargingIcons : dischargingIcons;
    var index = Math.min(ramp.length - 1, Math.max(0, Math.floor(percent / 10)));
    return ramp[index];
  }

  function duration(seconds) {
    if (!seconds || seconds <= 0)
      return "";
    var hours = Math.floor(seconds / 3600);
    var minutes = Math.round((seconds % 3600) / 60);
    return hours > 0 ? hours + "h " + minutes + "m" : minutes + "m";
  }

  tooltip: {
    if (!present)
      return "";
    var remaining = duration(discharging ? device.timeToEmpty : device.timeToFull);
    var state = discharging ? "discharging" : "charging";
    return percent + "% " + state + (remaining !== "" ? "\n" + remaining + (discharging ? " remaining" : " to full") : "");
  }

  visible: present
  implicitWidth: visible ? label.implicitWidth + Style.itemPaddingH * 2 : 0
  command: ["desktop-menu", "power"]

  IconLabel {
    id: label

    icon: root.icon
    text: root.percent + "%"
    // waybar coloured this by `states`; same thresholds.
    color: !root.discharging ? Color.barText : (root.percent <= 10 ? Color.barUrgent : (root.percent <= 20 ? Color.barAccent : Color.barText))
  }
}
