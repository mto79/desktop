import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import qs.Commons
import qs.Ui

// Network panel: the connection in use and what it is made of, Wi-Fi networks, what the
// machine is talking to, and a speed test.
//
// The top follows the battery panel: the state big, then the details -- address,
// gateway, DNS, public address -- each one click from the clipboard, since the reason to
// look one up is nearly always to paste it somewhere. The details come from
// desktop-network-details and describe the interface traffic actually leaves by: in the
// dock that is the wired link, and the Wi-Fi also up beside it is listed as a spare.
//
// The traffic section is a ten-second capture read back by desktop-network-traffic: who
// the machine talked to, by name, with the process behind it. It needs tshark and the
// wireshark group, and says so -- with the fix one click away -- when either is missing.
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
// VPN profiles have their own panel, VpnPanel, opened from the VPN icon.
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
      detailsProbe.reload();
      publicProbe.reload();
    } else {
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

  // --- Speed test ------------------------------------------------------------------
  //
  // desktop-speedtest prints the whole state on every line, so the last line read is the
  // result. It lives on the panel rather than inside the row: the panel is one instance
  // for the life of the shell, so the last result is still there when it is reopened.
  // A test outlives the panel being closed -- it is bounded to a few seconds, and
  // killing it halfway would only throw away a number already half paid for.

  property var speed: null

  readonly property bool speedRunning: speedtest.running

  function speedSummary(data) {
    if (!data)
      return "";
    var parts = [];
    if (data.download !== null)
      parts.push("\u2193 " + Math.round(data.download) + " Mbit/s");
    if (data.upload !== null)
      parts.push("\u2191 " + Math.round(data.upload) + " Mbit/s");
    if (data.latency !== null)
      parts.push(Math.round(data.latency) + " ms");
    return parts.join("  \u00b7  ");
  }

  Process {
    id: speedtest

    command: ["desktop-speedtest", "--json"]

    stdout: SplitParser {
      onRead: line => {
        try {
          root.speed = JSON.parse(line);
        } catch (e) {}
      }
    }

    onExited: exitCode => {
      // A script that died before it could say why still has to say something.
      if (exitCode !== 0 && (!root.speed || root.speed.stage !== "error"))
        root.speed = {
          stage: "error",
          error: "speed test exited with " + exitCode,
          latency: null,
          download: null,
          upload: null
        };
    }
  }

  function runSpeedtest() {
    if (speedtest.running)
      return;
    speed = null;
    speedtest.running = true;
  }

  // --- The connection in use -------------------------------------------------------

  property var details: null
  property var publicAddress: null
  property string copied: ""

  readonly property var primary: details ? details.primary : null
  readonly property bool primaryWifi: !!(primary && primary.type === "wifi")

  function stripPrefix(address) {
    return address ? address.split("/")[0] : "";
  }

  function linkSpeed(mbps) {
    if (!mbps)
      return "";
    return mbps >= 1000 ? (mbps / 1000) + "G" : mbps + "M";
  }

  // Copies with wl-copy, and says so on the row for a moment -- the only way to tell a
  // click did anything, with nothing visible changing.
  function copy(label, value) {
    if (!value)
      return;
    Quickshell.execDetached(["wl-copy", "--", value]);
    copied = label;
    copiedTimer.restart();
  }

  Timer {
    id: copiedTimer

    interval: 1400
    onTriggered: root.copied = ""
  }

  Process {
    id: detailsProbe

    command: ["desktop-network-details"]

    function reload() {
      if (!running)
        running = true;
    }

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          root.details = JSON.parse(text);
        } catch (e) {}
      }
    }
  }

  Process {
    id: publicProbe

    command: ["desktop-network-details", "--public"]

    function reload() {
      if (!running)
        running = true;
    }

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var data = JSON.parse(text);
          root.publicAddress = data.ip ? data : null;
        } catch (e) {}
      }
    }
  }

  // A link can change under an open panel -- the dock unplugged, Wi-Fi roaming.
  Timer {
    interval: 5000
    repeat: true
    running: root.visible
    onTriggered: detailsProbe.reload()
  }

  // --- Traffic ----------------------------------------------------------------------

  readonly property int trafficSeconds: 10

  property var traffic: null
  property real trafficStarted: 0
  property int trafficElapsed: 0

  readonly property bool trafficRunning: trafficProbe.running

  function bytes(value) {
    var units = ["B", "KB", "MB", "GB"];
    var unit = 0;
    while (value >= 1000 && unit < units.length - 1) {
      value /= 1000;
      unit++;
    }
    return (unit === 0 || value >= 10 ? Math.round(value) : value.toFixed(1)) + " " + units[unit];
  }

  // Addresses that never leave this network: private IPv4, IPv6 link-local and ULA.
  function isLocal(ip) {
    return /^(10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.|169\.254\.|fe80:|f[cd][0-9a-f]{2}:)/i.test(ip);
  }

  // Under the name: the program, and the address when a name took its place. A LAN
  // device announcing itself has neither, which is worth saying in words.
  function hostDetail(host) {
    var parts = [];
    if (host.process)
      parts.push(host.process);
    if (host.name)
      parts.push(host.ip);
    else if (!host.process)
      parts.push(isLocal(host.ip) ? "local network" : "no name");
    return parts.join("  ·  ");
  }

  function protocolSummary(data) {
    if (!data || !data.protocols || data.bytes <= 0)
      return "";
    // mDNS is devices on the network announcing themselves; the acronym says nothing.
    return data.protocols.slice(0, 4).map(function (p) {
      return (p.name === "MDNS" ? "LAN discovery" : p.name) + " " + Math.round(p.bytes / data.bytes * 100) + "%";
    }).join("  ·  ");
  }

  Process {
    id: trafficProbe

    command: ["desktop-network-traffic", "--seconds", String(root.trafficSeconds)]

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          root.traffic = JSON.parse(text);
        } catch (e) {
          root.traffic = {
            error: "capture",
            detail: "unreadable output"
          };
        }
      }
    }
  }

  Timer {
    interval: 1000
    repeat: true
    running: root.trafficRunning
    onTriggered: root.trafficElapsed = Math.round((Date.now() - root.trafficStarted) / 1000)
  }

  function watchTraffic() {
    if (trafficProbe.running)
      return;
    traffic = null;
    trafficStarted = Date.now();
    trafficElapsed = 0;
    trafficProbe.running = true;
  }

  function terminal(command) {
    root.close();
    Quickshell.execDetached(root.launch(["desktop-launch-floating-terminal-with-presentation"].concat(command)));
  }

  contentWidth: Style.popupWidth
  contentHeight: column.implicitHeight + Style.popupPadding * 2

  Column {
    id: column

    width: parent.width
    spacing: 2

    // --- The connection in use, big -----------------------------------------------------
    PanelHero {
      icon: {
        if (!root.primary)
          return "\u{f092b}";
        if (root.primaryWifi)
          return root.wifiIcon(root.activeNetwork);
        return root.primary.type === "ethernet" ? "\u{f0200}" : "\u{f0318}";
      }
      iconColor: root.primary ? Color.popupText : Color.popupMuted
      title: {
        if (!root.primary)
          return "Offline";
        if (root.primaryWifi && root.primary.wifi)
          return root.primary.wifi.ssid;
        return root.primary.connection || root.primary.iface;
      }
      status: {
        if (!root.primary)
          return "NO DEFAULT ROUTE";
        var parts = [];
        if (root.primaryWifi && root.primary.wifi) {
          var w = root.primary.wifi;
          parts.push(w.standard || "Wi-Fi", w.band, w.signal_dbm + " dBm");
        } else {
          parts.push(root.primary.type === "ethernet" ? "Wired" : root.primary.type);
          if (root.primary.speed)
            parts.push(root.linkSpeed(root.primary.speed).replace(/([GM])$/, " $1") + "bit/s");
        }
        parts.push(root.primary.iface);
        return parts.join("  ·  ");
      }
      value: {
        if (!root.primary)
          return "";
        if (root.primaryWifi)
          return root.activeNetwork ? Math.round(root.activeNetwork.signalStrength * 100) + "%" : "";
        return root.linkSpeed(root.primary.speed);
      }
    }

    // --- What it is made of, one click to copy ------------------------------------------
    Column {
      width: parent.width
      topPadding: 4
      bottomPadding: 4
      visible: !!root.primary

      Detail {
        label: "Address"
        value: root.primary && root.primary.ipv4.length > 0 ? root.primary.ipv4.join(", ") : ""
        copyValue: root.primary && root.primary.ipv4.length > 0 ? root.stripPrefix(root.primary.ipv4[0]) : ""
      }
      Detail {
        label: "Gateway"
        value: root.primary && root.primary.gateway ? root.primary.gateway : ""
      }
      Detail {
        label: "DNS"
        value: root.primary ? root.primary.dns.join(", ") : ""
        copyValue: root.primary && root.primary.dns.length > 0 ? root.primary.dns[0] : ""
      }
      Detail {
        label: "Public"
        value: root.publicAddress ? root.publicAddress.ip + "  ·  " + root.publicAddress.country : ""
        copyValue: root.publicAddress ? root.publicAddress.ip : ""
      }
      Detail {
        label: "IPv6"
        value: root.primary && root.primary.ipv6.length > 0 ? root.stripPrefix(root.primary.ipv6[0]) : ""
      }
      Detail {
        label: "MAC"
        value: root.primary && root.primary.mac ? root.primary.mac : ""
      }
      Detail {
        label: "Also up"
        // Names only: with addresses, two spares already overflow the line.
        value: root.details ? root.details.others.map(function (o) {
          return o.iface;
        }).join("  ·  ") : ""
        copyValue: ""
      }
    }

    PanelSection {
      title: "Wi-Fi"
      rule: true
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

    // Five rows of networks, then scroll -- three when wired, where Wi-Fi is the spare.
    // A busy street can produce forty of them, and with the details and traffic above
    // and below, the panel has to fit a laptop screen on its own.
    Flickable {
      id: networkList

      width: parent.width
      height: Math.min(contentHeight, Style.rowHeight * (root.primaryWifi ? 5 : 3))
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

    // --- Who the machine is talking to --------------------------------------------------
    PanelSection {
      title: "Traffic"
      value: root.traffic && root.traffic.iface ? root.bytes(root.traffic.bytes) + " in " + root.traffic.seconds + " s  ·  " + root.traffic.iface : ""
      rule: true
    }

    PanelRow {
      icon: "\u{f0b84}"
      label: {
        if (root.trafficRunning)
          return "Listening...  " + Math.max(0, root.trafficSeconds - root.trafficElapsed) + " s";
        return root.traffic && !root.traffic.error ? "Watch again" : "Watch traffic for " + root.trafficSeconds + " s";
      }
      sublabel: {
        if (root.trafficRunning)
          return "Capturing on the connection in use";
        if (root.traffic && !root.traffic.error)
          return root.protocolSummary(root.traffic);
        if (root.traffic && root.traffic.error === "missing")
          return "Needs tshark: click below to install";
        if (root.traffic && root.traffic.error === "permission")
          return "Not allowed to capture: needs the wireshark group";
        if (root.traffic && root.traffic.error)
          return root.traffic.detail || "Capture failed";
        return "Who this machine talks to, by name and program";
      }
      active: root.trafficRunning
      enabled: !root.trafficRunning && !(root.traffic && (root.traffic.error === "missing" || root.traffic.error === "permission"))
      onClicked: root.watchTraffic()
    }

    PanelRow {
      visible: !!(root.traffic && (root.traffic.error === "missing" || root.traffic.error === "permission"))
      icon: "\u{f01da}"
      label: "Install tshark"
      sublabel: "Runs the install in a terminal, asks for sudo"
      onClicked: root.terminal(["bash", Quickshell.env("DESKTOP_PATH") + "/install/packaging/wireshark.sh"])
    }

    Repeater {
      // Five, not all eight: the panel has to fit a laptop screen with the Wi-Fi list open.
      model: root.traffic && root.traffic.hosts ? root.traffic.hosts.slice(0, 5) : []

      delegate: PanelRow {
        required property var modelData

        icon: "\u{f059f}"
        label: modelData.name || modelData.ip
        sublabel: root.hostDetail(modelData)
        onClicked: root.copy(modelData.ip, modelData.name || modelData.ip)

        Text {
          text: root.copied === modelData.ip ? "copied" : root.bytes(modelData.bytes)
          color: root.copied === modelData.ip ? Color.popupAccent : Color.popupMuted
          font.family: Style.fontFamily
          font.pixelSize: Style.fontSize - 2
        }
      }
    }

    PanelRow {
      icon: "\u{f0cfb}"
      label: "Live view"
      sublabel: "Every lookup and connection as it happens, in a terminal"
      enabled: !(root.traffic && (root.traffic.error === "missing" || root.traffic.error === "permission"))
      onClicked: root.terminal(["desktop-network-traffic", "--live"])
    }

    PanelSection {
      title: "Speed test"
      value: {
        if (!root.speed)
          return "";
        if (root.speed.stage === "done" && root.speed.server)
          return "via " + root.speed.server;
        return "";
      }
      rule: true
    }

    PanelRow {
      icon: "\u{f04c5}"
      label: {
        if (!root.speedRunning)
          return root.speed ? "Run again" : "Run a speed test";
        var stage = root.speed ? root.speed.stage : "latency";
        return stage === "latency" ? "Measuring latency..." : "Testing " + stage + "...";
      }
      sublabel: {
        if (root.speed && root.speed.stage === "error")
          return root.speed.error;
        var summary = root.speedSummary(root.speed);
        return summary !== "" ? summary : "A few seconds, via Cloudflare";
      }
      active: root.speedRunning
      enabled: !root.speedRunning
      onClicked: root.runSpeedtest()
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
      icon: "\uf013"
      label: "Connection editor"
      sublabel: "Add or edit NetworkManager profiles"
      onClicked: {
        root.close();
        Quickshell.execDetached(root.launch(["uwsm", "app", "--", "nm-connection-editor"]));
      }
    }
  }

  // A label and a value on one line, copied on click. Rows with nothing to say hide.
  component Detail: Item {
    id: detail

    property string label: ""
    property string value: ""
    property string copyValue: value

    width: column.width
    height: visible ? 22 : 0
    visible: value !== ""

    Rectangle {
      anchors.fill: parent
      radius: 4
      color: detailArea.containsMouse && detail.copyValue !== "" ? Color.popupHover : "transparent"
    }

    Text {
      id: detailLabel

      anchors.left: parent.left
      anchors.leftMargin: 6
      anchors.verticalCenter: parent.verticalCenter
      width: 64
      text: detail.label
      color: Color.popupMuted
      font.family: Style.fontFamily
      font.pixelSize: Style.fontSize - 1
    }

    Text {
      anchors.left: detailLabel.right
      anchors.right: parent.right
      anchors.rightMargin: 6
      anchors.verticalCenter: parent.verticalCenter
      horizontalAlignment: Text.AlignRight
      text: root.copied === detail.label ? "copied" : detail.value
      color: root.copied === detail.label ? Color.popupAccent : Color.popupText
      font.family: Style.fontFamily
      font.pixelSize: Style.fontSize - 1
      elide: Text.ElideLeft
    }

    MouseArea {
      id: detailArea

      anchors.fill: parent
      hoverEnabled: true
      enabled: detail.copyValue !== ""
      cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
      onClicked: root.copy(detail.label, detail.copyValue)
    }
  }
}
