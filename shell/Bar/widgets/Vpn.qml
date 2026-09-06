import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui

// Active VPN tunnels.
//
// The state comes from desktop-status-openvpn rather than from nmcli directly, because
// there are two ways a tunnel gets up on this machine -- a NetworkManager profile of
// type vpn or wireguard, and a raw `openvpn --config` process started with sudo -- and
// that script is where the knowledge of both already lives.
BarItem {
  id: root

  property var names: []

  readonly property bool connected: names.length > 0
  // Off is worth showing: an icon that only exists while connected cannot be told apart
  // from a widget that has quietly stopped working. Set "hideWhenOff": true to reclaim
  // the space anyway.
  readonly property bool hideWhenOff: !!(widgetConfig && widgetConfig.hideWhenOff)
  // Off by default: which tunnel is up is panel detail, not glanceable state. Set
  // "showName": true to put it back in the bar.
  readonly property bool showName: !!(widgetConfig && widgetConfig.showName)

  visible: connected || !hideWhenOff

  // The names live here now that the bar shows only the glyph.
  tooltip: connected ? "VPN\n" + names.join("\n") : "No VPN connected"

  // The network panel carries the VPN list, so the bar icon opens the same place the
  // network icon does.
  onClicked: if (popups)
    popups.toggle("network", this)

  IconLabel {
    icon: root.connected ? "\u{f099d}" : "\u{f099c}"
    // The glyph carries the only thing that has to be readable in passing -- whether a
    // tunnel is up. A second one is worth counting, since the glyph cannot say so.
    text: {
      if (root.showName && root.names.length === 1)
        return root.names[0];
      return root.names.length > 1 ? String(root.names.length) : "";
    }
    color: root.connected ? Color.barText : Color.barMuted
  }

  Process {
    id: probe

    command: ["desktop-status-openvpn", "--names"]

    stdout: StdioCollector {
      onStreamFinished: {
        var list = [];
        var lines = text.split("\n");
        for (var i = 0; i < lines.length; i++)
          if (lines[i].trim() !== "")
            list.push(lines[i].trim());
        root.names = list;
      }
    }
  }

  Timer {
    interval: 5000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!probe.running)
      probe.running = true
  }
}
