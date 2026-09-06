import QtQuick
import Quickshell.Networking
import qs.Commons
import qs.Ui

// Connectivity: a Wi-Fi signal ramp with the network's name, or a single glyph for
// ethernet.
//
// Reads Quickshell's NetworkManager binding rather than polling nmcli, so the name
// changes the moment the connection does, and the widget and its panel cannot disagree
// about what is connected. The service only starts once something binds to it, which
// every property below does.
BarItem {
  id: root

  readonly property var devices: Networking.devices ? Networking.devices.values : []

  readonly property var wifiDevice: {
    for (var i = 0; i < devices.length; i++)
      if (devices[i].type === DeviceType.Wifi)
        return devices[i];
    return null;
  }

  readonly property var wiredDevice: {
    for (var i = 0; i < devices.length; i++)
      if (devices[i].type === DeviceType.Wired)
        return devices[i];
    return null;
  }

  // The connected network is in the model whether or not a scan is running, so this
  // costs nothing while the panel is closed.
  readonly property var activeWifi: {
    if (!wifiDevice || !wifiDevice.networks)
      return null;
    var list = wifiDevice.networks.values;
    for (var i = 0; i < list.length; i++)
      if (list[i].connected)
        return list[i];
    return null;
  }

  readonly property string kind: {
    if (wiredDevice && wiredDevice.connected)
      return "ethernet";
    if (activeWifi)
      return "wifi";
    return "disconnected";
  }

  readonly property string ssid: activeWifi ? activeWifi.name : ""
  readonly property int signal: activeWifi ? Math.round(activeWifi.signalStrength * 100) : 0

  // Both off gives the pre-panel behaviour back: a bare icon.
  readonly property bool showSsid: !(widgetConfig && widgetConfig.showSsid === false)
  readonly property bool showSignal: !!(widgetConfig && widgetConfig.showSignal)

  readonly property var wifiIcons: ["󰤯", "󰤟", "󰤢", "󰤥", "󰤨"]
  readonly property string icon: {
    if (kind === "ethernet")
      return "󰲝";
    if (kind === "disconnected")
      return "󰖪";
    var index = Math.min(wifiIcons.length - 1, Math.max(0, Math.floor(activeWifi.signalStrength * 4.999)));
    return wifiIcons[index];
  }

  readonly property string label: {
    if (kind !== "wifi")
      return "";
    var parts = [];
    if (showSsid && ssid !== "")
      parts.push(ssid);
    if (showSignal)
      parts.push(signal + "%");
    return parts.join(" ");
  }

  tooltip: {
    if (kind === "ethernet")
      return "Wired\n" + (wiredDevice.name || "");
    if (kind === "disconnected")
      return "Disconnected";
    return ssid + "\n" + signal + "% signal";
  }

  // Left click opens the network panel; right click keeps impala one gesture away,
  // since joining a new secured network still needs its passphrase prompt.
  panelId: "network"

  onClicked: if (popups)
    popups.toggle(root.panelId, this)
  rightCommand: ["desktop-launch-wifi"]

  IconLabel {
    icon: root.icon
    text: root.label
    color: root.kind === "disconnected" ? Color.barMuted : Color.barText
  }
}
