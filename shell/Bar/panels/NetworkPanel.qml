import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import qs.Commons
import qs.Ui

// Network panel: Wi-Fi networks, wired link state, and VPN profiles.
//
// Wi-Fi comes from Quickshell's Networking service, which is a NetworkManager binding
// -- no nmcli polling, unlike the bar widget that predates this panel. Two things about
// that service shape this file:
//
//   * It only starts once something *binds* to it. A one-shot JavaScript read of
//     Networking.devices returns an empty model, so every access here goes through a
//     declarative property rather than being fetched inside a handler.
//   * Scanning is off until asked for, and the scan is a device-global setting -- the
//     reason PopupHost keeps exactly one instance of this panel. It runs only while the
//     panel is open, so a closed bar is not burning radio time.
//
// VPN still goes through nmcli: the service models devices and Wi-Fi, and has no
// concept of a VPN profile.
Popup {
  id: root

  readonly property string panelId: "network"

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

  readonly property bool wifiEnabled: Networking.wifiEnabled
  readonly property var activeNetwork: {
    for (var i = 0; i < networks.length; i++)
      if (networks[i].connected)
        return networks[i];
    return null;
  }

  // Keyboard state. The panel holds focus while it is open, so typing filters the list
  // and the arrows move a cursor through it -- the reason a scan of forty networks is
  // navigable at all without reaching for the mouse.
  property string filter: ""
  property int cursor: -1

  // The network waiting for a passphrase, if any. Non-null swaps the list for a field.
  property var pskTarget: null

  readonly property var visibleNetworks: {
    if (filter === "")
      return networks;
    var needle = filter.toLowerCase();
    var out = [];
    for (var i = 0; i < networks.length; i++)
      if (networks[i].name.toLowerCase().indexOf(needle) !== -1)
        out.push(networks[i]);
    return out;
  }

  function moveCursor(delta) {
    var count = visibleNetworks.length;
    if (count === 0) {
      cursor = -1;
      return;
    }
    cursor = cursor < 0 ? (delta > 0 ? 0 : count - 1) : (cursor + delta + count) % count;
    ensureCursorVisible();
  }

  // Rows differ in height -- a sublabel makes one taller -- so the row itself is asked
  // where it is rather than multiplying an assumed row height.
  function ensureCursorVisible() {
    if (cursor < 0 || cursor >= networkColumn.children.length)
      return;
    var row = networkColumn.children[cursor];
    if (!row)
      return;
    if (row.y < networkList.contentY)
      networkList.contentY = row.y;
    else if (row.y + row.height > networkList.contentY + networkList.height)
      networkList.contentY = row.y + row.height - networkList.height;
  }

  function promptForPsk(network) {
    pskTarget = network;
    pskField.text = "";
    pskError = "";
    // Focus has to move to the field, or the panel's own key handling would eat the
    // passphrase as filter text.
    Qt.callLater(function () {
      pskField.take();
    });
  }

  property string pskError: ""

  function submitPsk() {
    if (!pskTarget)
      return;
    if (pskField.text === "") {
      pskError = "Passphrase is empty";
      return;
    }
    pskTarget.connectWithPsk(pskField.text);
    cancelPsk();
  }

  function cancelPsk() {
    pskTarget = null;
    pskError = "";
    pskField.text = "";
    pskField.release();
    root.takeFocus();
  }

  onKeyPressed: event => {
    // The field owns the keyboard while it is up.
    if (pskTarget)
      return;

    if (event.key === Qt.Key_Down) {
      root.moveCursor(1);
      event.accepted = true;
    } else if (event.key === Qt.Key_Up) {
      root.moveCursor(-1);
      event.accepted = true;
    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      if (root.cursor >= 0 && root.cursor < root.visibleNetworks.length)
        root.activate(root.visibleNetworks[root.cursor]);
      event.accepted = true;
    } else if (event.key === Qt.Key_Backspace) {
      root.filter = root.filter.slice(0, -1);
      root.cursor = -1;
      event.accepted = true;
    } else if (event.key === Qt.Key_Escape && root.filter !== "") {
      // Escape clears a filter before it closes the panel, the way a search box does.
      root.filter = "";
      root.cursor = -1;
      event.accepted = true;
    } else if (event.text !== "" && event.text >= " ") {
      root.filter += event.text;
      root.cursor = -1;
      event.accepted = true;
    }
  }

  // Debounced snapshot of the scan results, for the same reason AudioPanel keeps one:
  // a Repeater rebuilt from inside the model's own change signal is a crash waiting to
  // happen, and a scan churns the list every few seconds.
  property var networks: []

  readonly property var liveNetworks: (wifiDevice && wifiDevice.networks) ? wifiDevice.networks.values : []

  function rebuild() {
    var list = [];
    for (var i = 0; i < liveNetworks.length; i++)
      if (liveNetworks[i] && liveNetworks[i].name !== "")
        list.push(liveNetworks[i]);

    // Connected first, then saved profiles, then by signal: the rows you are most
    // likely to want are the ones that do not move around as the scan updates.
    list.sort(function (a, b) {
      if (a.connected !== b.connected)
        return a.connected ? -1 : 1;
      if (a.known !== b.known)
        return a.known ? -1 : 1;
      if (a.signalStrength !== b.signalStrength)
        return b.signalStrength - a.signalStrength;
      return a.name.localeCompare(b.name);
    });
    networks = list;
  }

  Timer {
    id: rebuildTimer

    interval: 75
    repeat: false
    onTriggered: root.rebuild()
  }

  onLiveNetworksChanged: rebuildTimer.restart()

  // Scan only while the panel is open. `when` matters: without it the binding would
  // leave the scanner running after the panel closes.
  Binding {
    target: root.wifiDevice
    property: "scannerEnabled"
    value: root.visible
    when: root.wifiDevice !== null
  }

  onVisibleChanged: {
    if (visible) {
      root.rebuild();
      vpnProbe.reload();
    } else {
      root.vpnError = "";
      root.filter = "";
      root.cursor = -1;
      root.pskTarget = null;
      root.pskError = "";
    }
  }

  readonly property var wifiIcons: ["\u{f091f}", "\u{f091f}", "\u{f0922}", "\u{f0925}", "\u{f0928}"]

  function wifiIcon(network) {
    if (!network)
      return "\u{f092b}";
    var index = Math.min(4, Math.max(0, Math.floor(network.signalStrength * 4.999)));
    return wifiIcons[index];
  }

  // Detached launches carry $HOME as their cwd for the reason spelled out in BarItem:
  // a cwd-relative path in someone else's config file is not this shell's business,
  // but inheriting an arbitrary directory is what breaks it.
  function launch(command) {
    return {
      command: command,
      workingDirectory: Quickshell.env("HOME")
    };
  }

  function isOpen(network) {
    return network && network.security === WifiSecurityType.Open;
  }

  function securityLabel(network) {
    if (!network)
      return "";
    if (root.isOpen(network))
      return "open";
    return network.known ? "saved" : "secured";
  }

  // Known networks and open ones connect straight away; anything else asks for its
  // passphrase here. That prompt is only possible because the panel is a layer surface
  // that can hold keyboard focus -- on the old popup it had to hand off to impala.
  function activate(network) {
    if (!network)
      return;
    if (network.connected) {
      network.disconnect();
      return;
    }
    if (network.known || root.isOpen(network)) {
      network.connect();
      return;
    }
    root.promptForPsk(network);
  }

  // --- VPN ------------------------------------------------------------------------
  //
  // NetworkManager profiles of type vpn or wireguard. Raw `openvpn --config` processes
  // are the other half of the story on this machine -- see desktop-status-openvpn --
  // and those stay with the terminal flow in the Advanced section, because starting one
  // needs sudo.

  property var vpns: []
  property string vpnError: ""
  property string vpnBusy: ""

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

    property string target: ""

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
    vpnAction.target = entry.name;
    vpnAction.command = ["nmcli", "connection", entry.active ? "down" : "up", "id", entry.name];
    vpnAction.running = true;
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
      title: "Wi-Fi"
      value: {
        if (root.filter !== "")
          return "filter: " + root.filter;
        if (!root.wifiEnabled)
          return "off";
        return root.activeNetwork ? root.activeNetwork.name : "not connected";
      }
    }

    PanelRow {
      icon: root.wifiEnabled ? "\u{f0928}" : "\u{f092d}"
      label: root.wifiEnabled ? "Wi-Fi on" : "Wi-Fi off"
      sublabel: Networking.wifiHardwareEnabled ? "" : "blocked in hardware"
      enabled: Networking.wifiHardwareEnabled
      active: root.wifiEnabled
      onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
    }

    // Six rows of networks, then scroll. A busy street can produce forty of them, and
    // the panel is not allowed to grow into a full-screen list.
    Flickable {
      id: networkList

      width: parent.width
      height: Math.min(contentHeight, Style.rowHeight * 6)
      contentHeight: networkColumn.implicitHeight
      visible: root.wifiEnabled && root.visibleNetworks.length > 0 && !root.pskTarget
      clip: true
      boundsBehavior: Flickable.StopAtBounds

      Column {
        id: networkColumn

        width: networkList.width

        Repeater {
          model: root.visibleNetworks

          delegate: PanelRow {
            required property var modelData
            required property int index

            cursor: root.cursor === index
            icon: root.wifiIcon(modelData)
            label: modelData ? modelData.name : ""
            sublabel: {
              if (!modelData)
                return "";
              if (modelData.stateChanging)
                return modelData.connected ? "disconnecting..." : "connecting...";
              return root.securityLabel(modelData);
            }
            active: modelData ? modelData.connected : false

            onClicked: root.activate(modelData)
            // Forgetting is destructive and easy to hit by accident in a list this
            // long, so it stays on the right button, like mute on the audio widget.
            onRightClicked: if (modelData && modelData.known)
              modelData.forget()

            Text {
              text: modelData ? Math.round(modelData.signalStrength * 100) + "%" : ""
              color: Color.popupMuted
              font.family: Style.fontFamily
              font.pixelSize: Style.fontSize - 2
            }
          }
        }
      }
    }

    // Passphrase prompt. Takes the list's place rather than sitting under it, so the
    // panel does not change height at the moment you are typing into it.
    Item {
      width: parent.width
      height: visible ? 62 : 0
      visible: root.pskTarget !== null

      Text {
        id: pskLabel

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.leftMargin: 6
        anchors.right: parent.right
        anchors.rightMargin: 6
        height: 20
        text: {
          if (root.pskError !== "")
            return root.pskError;
          return root.pskTarget ? "Passphrase for " + root.pskTarget.name : "";
        }
        color: root.pskError !== "" ? Color.popupUrgent : Color.popupMuted
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSize - 2
        elide: Text.ElideRight
      }

      PanelInput {
        id: pskField

        anchors.top: pskLabel.bottom
        anchors.left: parent.left
        anchors.leftMargin: 6
        anchors.right: parent.right
        anchors.rightMargin: 6
        echoMode: TextInput.Password
        placeholder: "Enter to connect, Escape to cancel"

        onAccepted: root.submitPsk()
        onCancelled: root.cancelPsk()
      }
    }

    PanelSection {
      title: "Wired"
      value: root.wiredDevice && root.wiredDevice.connected ? "connected" : "no link"
      rule: true
      visible: !!root.wiredDevice
    }

    // Informational: pulling an ethernet link down by misclick is a worse outcome than
    // having to reach for the settings app on the rare occasion you mean it.
    PanelRow {
      visible: !!root.wiredDevice
      icon: "\u{f0318}"
      label: root.wiredDevice ? root.wiredDevice.name : ""
      sublabel: root.wiredDevice && root.wiredDevice.address ? root.wiredDevice.address : ""
      active: root.wiredDevice ? root.wiredDevice.connected : false
      enabled: false
    }

    PanelSection {
      title: "VPN"
      value: {
        var count = 0;
        for (var i = 0; i < root.vpns.length; i++)
          if (root.vpns[i].active)
            count++;
        return count > 0 ? count + " active" : "off";
      }
      rule: true
      visible: root.vpns.length > 0
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

    PanelRow {
      icon: "\uf1eb"
      label: "Open impala"
      sublabel: "Wi-Fi TUI, joins new networks"
      onClicked: {
        root.close();
        Quickshell.execDetached(root.launch(["desktop-launch-wifi"]));
      }
    }

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
      icon: "\uf013"
      label: "Connection editor"
      sublabel: "Add or edit NetworkManager profiles"
      onClicked: {
        root.close();
        Quickshell.execDetached(root.launch(["uwsm", "app", "--", "nm-connection-editor"]));
      }
    }
  }
}
