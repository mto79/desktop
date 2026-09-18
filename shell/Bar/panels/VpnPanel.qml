import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// VPN panel: NetworkManager's VPN and WireGuard profiles, one click to bring each up or
// down, and the way into the OpenVPN configs NetworkManager does not know about.
//
// This used to be the bottom third of the network panel, which the VPN icon opened as
// well. Two icons opening one panel made the VPN icon a second network button, and put
// the tunnels under a Wi-Fi list that could scroll to forty rows. Now each icon opens
// what it shows.
//
// Profiles go through nmcli: Quickshell's Networking service models devices and Wi-Fi,
// and has no concept of a VPN profile.
Popup {
  id: root

  readonly property string panelId: "vpn"

  property var vpns: []
  property string vpnError: ""
  property string vpnBusy: ""

  readonly property int activeCount: {
    var count = 0;
    for (var i = 0; i < vpns.length; i++)
      if (vpns[i].active)
        count++;
    return count;
  }

  // Detached launches carry $HOME as their cwd for the reason spelled out in BarItem.
  function launch(command) {
    return {
      command: command,
      workingDirectory: Quickshell.env("HOME")
    };
  }

  // nmcli -t escapes a literal colon inside a field as "\:", so a plain split() would
  // tear a profile name like "work:eu" in half.
  function splitFields(line) {
    var fields = [];
    var current = "";
    for (var i = 0; i < line.length; i++) {
      var c = line.charAt(i);
      if (c === "\\" && i + 1 < line.length) {
        current += line.charAt(++i);
      } else if (c === ":") {
        fields.push(current);
        current = "";
      } else {
        current += c;
      }
    }
    fields.push(current);
    return fields;
  }

  Process {
    id: vpnProbe

    command: ["nmcli", "-t", "-f", "NAME,TYPE,STATE", "connection", "show"]

    function reload() {
      if (!running)
        running = true;
    }

    stdout: StdioCollector {
      onStreamFinished: {
        var lines = text.split("\n");
        var list = [];
        for (var i = 0; i < lines.length; i++) {
          if (lines[i] === "")
            continue;
          var parts = root.splitFields(lines[i]);
          if (parts.length < 3)
            continue;
          if (parts[1] !== "vpn" && parts[1] !== "wireguard")
            continue;
          list.push({
            name: parts[0],
            type: parts[1],
            active: parts[2] === "activated"
          });
        }
        root.vpns = list;
      }
    }
  }

  Process {
    id: vpnAction

    stderr: StdioCollector {
      onStreamFinished: root.vpnError = text.trim().split("\n").pop()
    }

    onExited: exitCode => {
      root.vpnBusy = "";
      if (exitCode === 0)
        root.vpnError = "";
      vpnProbe.reload();
    }
  }

  function toggleVpn(entry) {
    if (!entry || vpnBusy !== "" || vpnAction.running)
      return;
    vpnError = "";
    vpnBusy = entry.name;
    vpnAction.command = ["nmcli", "connection", entry.active ? "down" : "up", "id", entry.name];
    vpnAction.running = true;
  }

  onVisibleChanged: {
    if (visible)
      vpnProbe.reload();
    else
      root.vpnError = "";
  }

  Timer {
    interval: 5000
    repeat: true
    running: root.visible
    triggeredOnStart: true
    onTriggered: vpnProbe.reload()
  }

  contentWidth: Style.popupWidth
  contentHeight: column.implicitHeight + Style.popupPadding * 2

  Column {
    id: column

    width: parent.width
    spacing: 2

    PanelSection {
      title: "VPN"
      value: root.activeCount > 0 ? root.activeCount + " active" : "off"
    }

    Repeater {
      model: root.vpns

      delegate: PanelRow {
        required property var modelData

        icon: modelData.active ? "\u{f099d}" : "\u{f099c}"
        label: modelData.name
        sublabel: root.vpnBusy === modelData.name ? (modelData.active ? "disconnecting..." : "connecting...") : modelData.type
        active: modelData.active
        enabled: root.vpnBusy === ""
        onClicked: root.toggleVpn(modelData)
      }
    }

    // A panel of its own has to say when it is empty; as a section it could just hide.
    PanelRow {
      visible: root.vpns.length === 0
      icon: "\u{f099c}"
      label: "No VPN profiles"
      sublabel: "Add one in the connection editor"
      enabled: false
    }

    // nmcli fails rather than prompting when a profile's secrets are not stored, and
    // silently doing nothing would look like a broken panel.
    Item {
      width: parent.width
      height: visible ? 22 : 0
      visible: root.vpnError !== ""

      Text {
        anchors.left: parent.left
        anchors.leftMargin: 6
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        text: root.vpnError
        color: Color.popupUrgent
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSize - 2
        elide: Text.ElideRight
      }
    }

    PanelSection {
      title: "Advanced"
      rule: true
    }

    // Raw `openvpn --config` tunnels need sudo to start, so they stay with the terminal.
    PanelRow {
      icon: "\u{f0993}"
      label: "OpenVPN configs"
      sublabel: "Profiles outside NetworkManager"
      onClicked: {
        root.close();
        Quickshell.execDetached(root.launch(["desktop-launch-floating-terminal-with-presentation", "desktop-launch-openvpn"]));
      }
    }

    PanelRow {
      icon: ""
      label: "Connection editor"
      sublabel: "Add or edit VPN profiles"
      onClicked: {
        root.close();
        Quickshell.execDetached(root.launch(["uwsm", "app", "--", "nm-connection-editor"]));
      }
    }
  }
}
