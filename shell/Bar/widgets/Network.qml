import QtQuick
import Quickshell.Io
import Quickshell.Networking
import qs.Commons
import qs.Ui
import "tether.js" as Tether

// Connectivity: a Wi-Fi signal ramp coloured by strength, a phone for a USB-tethered
// one, or a single glyph for ethernet.
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

  // The wired device that is connected, when one is: a dock adds a second wired device
  // beside the laptop's own, and the first in the list is not always the one with the
  // cable in it -- which showed Wi-Fi on a machine that was on the cable.
  readonly property var wiredDevice: {
    var first = null;
    for (var i = 0; i < devices.length; i++)
      if (devices[i].type === DeviceType.Wired) {
        if (devices[i].connected)
          return devices[i];
        if (!first)
          first = devices[i];
      }
    return first;
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

  // A phone sharing its connection over USB is a wired device to NetworkManager; the
  // driver behind the interface is what says otherwise. See tether.js.
  property bool tethered: false

  FileView {
    path: root.kind === "ethernet" && root.wiredDevice.name ? "/sys/class/net/" + root.wiredDevice.name + "/device/uevent" : ""
    onLoaded: root.tethered = Tether.isTether(text())
    onLoadFailed: root.tethered = false
    onPathChanged: if (path === "")
      root.tethered = false
  }

  readonly property string ssid: activeWifi ? activeWifi.name : ""
  readonly property int signal: activeWifi ? Math.round(activeWifi.signalStrength * 100) : 0

  // The kernel names its counters after the interface, and NetworkManager's device name
  // is that interface -- so the widget and the throughput it prints cannot end up
  // describing two different links.
  readonly property string iface: {
    if (kind === "ethernet")
      return wiredDevice.name || "";
    if (kind === "wifi" && wifiDevice)
      return wifiDevice.name || "";
    return "";
  }

  // Bytes per second, from the delta between two reads of the kernel's cumulative
  // counters. Zero until the second read, the way Cpu.qml's first tick is.
  property real rxRate: 0
  property real txRate: 0
  property real lastRx: 0
  property real lastTx: 0
  property real lastAt: 0

  // Speed rather than the network's name is the default: which network you are on is a
  // thing you already know, and changes perhaps twice a day. What it is doing right now
  // is the part worth a slot on the bar. The name is still in the tooltip, and
  // {"showSsid": true} puts it back beside the icon.
  readonly property bool showSsid: !!(widgetConfig && widgetConfig.showSsid)
  readonly property bool showSignal: !!(widgetConfig && widgetConfig.showSignal)
  readonly property bool showSpeed: !(widgetConfig && widgetConfig.showSpeed === false)

  // The speeds are what this widget is for, and they are also the widest text on the bar,
  // so on a narrow screen they were the first thing dropped. Asked last instead, unless
  // shell.json says {"keepText": false}.
  compactOrder: widgetConfig && widgetConfig.keepText === false ? 0 : 1

  // Binary units, matching what the disk and memory widgets beside it already print.
  //
  // Always four characters wide, padded on the left. The label changes every two seconds,
  // and a label that changes width moves every widget beside it -- and every panel
  // hanging under one of them, so an open panel shuffled sideways as a download ran. The
  // bar font is monospace, so a fixed count of characters is a fixed width. Moving up a
  // unit at 1000 rather than 1024 is what caps it at four: 1000-1023 would be "1010K",
  // and is "1.0M" instead. Rounding can land on 1000 too, hence the second check.
  function rate(bytes) {
    var units = ["B", "K", "M", "G"];
    var value = bytes;
    var unit = 0;
    while (value >= 1000 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    var shown = unit === 0 || value >= 9.95 ? String(Math.round(value)) : value.toFixed(1);
    if (shown.length > 3 && unit < units.length - 1) {
      shown = (value / 1024).toFixed(1);
      unit++;
    }
    return (shown + units[unit]).padStart(4, " ");
  }

  function sample(text) {
    if (iface === "")
      return;

    var lines = text.split("\n");
    for (var i = 0; i < lines.length; i++) {
      // "  wlp3s0f0: 9320487273 7735843 ..." -- the name carries the colon, and the
      // field is right-aligned, so a plain split on whitespace loses the separation
      // when the byte count is wide enough to touch it.
      var parts = lines[i].replace(":", " ").trim().split(/\s+/);
      if (parts[0] !== iface)
        continue;

      var rx = parseInt(parts[1], 10) || 0;
      var tx = parseInt(parts[9], 10) || 0;
      var now = Date.now();

      // A counter that went backwards means the interface was reset, not that the link
      // ran in reverse. Re-seed instead of printing a nonsense rate.
      if (lastAt > 0 && rx >= lastRx && tx >= lastTx) {
        var seconds = (now - lastAt) / 1000;
        if (seconds > 0) {
          rxRate = (rx - lastRx) / seconds;
          txRate = (tx - lastTx) / seconds;
        }
      } else {
        rxRate = 0;
        txRate = 0;
      }

      lastRx = rx;
      lastTx = tx;
      lastAt = now;
      return;
    }
  }

  FileView {
    id: netdev

    path: "/proc/net/dev"
    onLoaded: root.sample(text())
  }

  // Two seconds, as Cpu.qml uses: fast enough to see a download start, slow enough that
  // the number is readable rather than a blur.
  Timer {
    interval: 2000
    running: root.iface !== ""
    repeat: true
    triggeredOnStart: true
    onTriggered: netdev.reload()
  }

  readonly property var wifiIcons: ["󰤯", "󰤟", "󰤢", "󰤥", "󰤨"]
  readonly property string icon: {
    // A cable, which nobody takes for the Wi-Fi fan at a glance.
    if (kind === "ethernet")
      return tethered ? "\u{f011c}" : "\u{f0200}";
    if (kind === "disconnected")
      return "󰖪";
    var index = Math.min(wifiIcons.length - 1, Math.max(0, Math.floor(activeWifi.signalStrength * 4.999)));
    return wifiIcons[index];
  }

  readonly property string label: {
    if (kind === "disconnected")
      return "";
    var parts = [];
    if (showSsid && ssid !== "")
      parts.push(ssid);
    if (showSignal && kind === "wifi")
      parts.push(signal + "%");
    // Ethernet gets a readout too now. It had no label at all before, because the only
    // thing on offer was a network name it does not have.
    if (showSpeed && iface !== "")
      parts.push("\u2193" + rate(rxRate) + " \u2191" + rate(txRate));
    return parts.join(" ");
  }

  tooltip: {
    if (kind === "ethernet")
      return (tethered ? "Phone tethering\n" : "Wired\n") + (wiredDevice.name || "");
    if (kind === "disconnected")
      return "Disconnected";
    return ssid + "\n" + signal + "% signal";
  }

  // Left click opens the network panel; right click keeps impala one gesture away,
  // since joining a new secured network still needs its passphrase prompt.
  // More than a trickle either way: a download, an upload, a call. The idle chatter of a
  // connected machine stays under this and leaves the icon still.
  readonly property bool busy: kind !== "disconnected" && (rxRate + txRate) > 256 * 1024

  panelId: "network"

  onClicked: if (popups)
    popups.toggle(root.panelId, this)
  rightCommand: ["desktop-launch-wifi"]

  // The signal ramp in colour as well as shape: the gauge the battery and disks use,
  // read the other way round, so a full signal is good and a fading one goes through
  // caution to urgent. Blended rather than stepped, so 55% and 75% are told apart though
  // they share a glyph. Busy still wins -- blue means working, wherever it is on the bar.
  readonly property color baseColor: root.kind === "disconnected" ? Color.barMuted : (root.busy ? Color.barAccent : Color.barText)

  IconLabel {
    icon: root.icon
    text: root.label
    color: root.baseColor
    iconColor: root.kind === "wifi" && !root.busy ? Color.gauge(1 - root.activeWifi.signalStrength) : root.baseColor
    lively: root.busy
  }
}
