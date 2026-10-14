import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

// Infrastructure, under two headings.
//
// "Clusters" is each cluster as a tile, from desktop-dash infra, which asks every cluster
// ocl knows that there is a token for, all at once. "Network" is where this machine is:
// the place, the link it is on, the router and what lies beyond, drawn as the path a
// packet takes and said again in sentences. That is desktop-dash network, which asks
// NetworkManager and the routing table and nobody outside.
ColumnLayout {
  id: page

  property var info: null
  // The network, asked separately: it changes when a cable is pulled, not every two minutes.
  property var net: null
  property bool active: false

  readonly property var headings: ["clusters", "network", "bluetooth"]
  readonly property var titles: ({
      "clusters": "Clusters",
      "network": "Network",
      "bluetooth": "Bluetooth"
    })
  property int section: 0
  readonly property string heading: headings[section]

  spacing: Style.overviewSpacing

  function step(delta) {
    section = (section + delta + headings.length) % headings.length;
  }

  function choose(name) {
    var at = headings.indexOf(name);
    if (at === -1)
      return false;
    section = at;
    return true;
  }

  // --- network: what the picture is made of ----------------------------------------------
  readonly property var link: net && net.links && net.links.length > 0 ? net.links[0] : null
  readonly property var tunnel: net && net.vpn && net.vpn.length > 0 ? net.vpn[0] : null
  readonly property bool online: !!net && net.online === "full"
  readonly property color placeTone: {
    var kind = net && net.place ? net.place.kind : "none";
    return kind === "home" ? Color.good : kind === "work" ? Color.popupAccent : kind === "away" ? Color.caution : kind === "none" ? Color.popupUrgent : Color.popupText;
  }

  // The box whose details are open under the picture: "machine", "router", "internet" or
  // "vpn" ("Behind the VPN" opens the same). Clicking it again closes them. Kept across the
  // refreshes every ten seconds, which is why it is a name and not the box's data.
  property string chosen: ""
  onHeadingChanged: chosen = ""

  function pick(key) {
    chosen = chosen === key ? "" : key;
  }

  // What the open box says about itself: facts as label and value, and a list of routes
  // where there is one. Everything here is what NetworkManager and the routing table
  // already hold; nothing is looked up to fill it.
  readonly property var details: {
    var n = net;
    if (!n || chosen === "")
      return null;
    function route(r) {
      return r.dst + (r.via ? "  via " + r.via : "") + (r.metric ? "  ·  " + r.metric : "") + (r.vpn_server ? "  ·  the VPN server" : "");
    }
    if (chosen === "machine") {
      var facts = [];
      var all = n.links.concat(n.vpn);
      for (var i = 0; i < all.length; i++) {
        var l = all[i];
        facts.push([l.dev, (l.kind === "vpn" ? "VPN " : l.kind === "wifi" ? "Wi-Fi " : "cable ") + l.connection + (l.primary ? "  ·  the way out" : "")]);
        facts.push(["", (l.addresses && l.addresses.length ? l.addresses.join("  ") : "no address")]);
      }
      return {
        "icon": "\u{f0322}",
        "title": "This machine",
        "tone": placeTone,
        "facts": facts,
        "routesTitle": "",
        "routes": []
      };
    }
    if (chosen === "router") {
      var l2 = link;
      var f2 = [["Router", n.router.address || "none"], ["Answers", n.router.ms !== null && n.router.ms !== undefined ? n.router.ms + " ms" : "not to a ping"]];
      if (l2) {
        f2.push(["Over", (l2.kind === "wifi" ? "Wi-Fi " + (l2.ssid || l2.connection) : "cable  ·  " + l2.connection) + "  ·  " + l2.dev]);
        if (l2.kind === "wifi" && l2.signal)
          f2.push(["Signal", l2.signal + "%" + (l2.band ? "  ·  " + l2.band : "")]);
        f2.push(["This machine", l2.address || "no address"]);
        f2.push(["Name servers", l2.dns.length ? l2.dns.join("  ") : "none given"]);
        if (l2.domains.length)
          f2.push(["Search domains", l2.domains.join("  ")]);
      }
      return {
        "icon": "\u{f0469}",
        "title": "Router",
        "tone": placeTone,
        "facts": f2,
        "routesTitle": l2 ? "Routes on " + l2.dev : "",
        "routes": l2 ? l2.route_list.map(route) : []
      };
    }
    if (chosen === "internet") {
      var f3 = [["Internet", online ? "reachable" : n.online === "portal" ? "behind a login page" : n.online === "none" ? "no connection" : "not reachable"]];
      f3.push(["Name servers", n.dns.length ? n.dns.join("  ") : "none"]);
      if (n.domains.length)
        f3.push(["Search domains", n.domains.join("  ")]);
      if (tunnel)
        f3.push(["VPN", tunnel.all ? "takes all traffic" : "takes " + tunnel.routes + " networks; the rest goes out directly"]);
      return {
        "icon": "\u{f01e7}",
        "title": "Internet",
        "tone": online ? Color.good : Color.popupUrgent,
        "facts": f3,
        "routesTitle": "Ways out, the first is taken",
        "routes": (n.defaults || []).map(function (d) {
          return "default  via " + (d.via || "-") + "  ·  " + d.dev + "  ·  metric " + d.metric;
        })
      };
    }
    if (chosen === "vpn" && tunnel) {
      var f4 = [["Connection", tunnel.connection], ["Device", tunnel.dev], ["Address", tunnel.address || "none"], ["Traffic", tunnel.all ? "all of it" : tunnel.routes + " networks; the rest goes out directly"]];
      if (tunnel.gateways && tunnel.gateways.length)
        f4.push(["Through", tunnel.gateways.join("  ")]);
      f4.push(["Name servers", tunnel.dns.length ? tunnel.dns.join("  ") : "the ones of the link"]);
      if (tunnel.domains.length)
        f4.push(["Search domains", tunnel.domains.join("  ")]);
      // One gateway for all: said once above, not on every line.
      var single = tunnel.gateways && tunnel.gateways.length === 1;
      return {
        "icon": "\u{f099d}",
        "title": "VPN " + tunnel.connection,
        "tone": Color.popupAccent,
        "facts": f4,
        "routesTitle": (tunnel.route_list ? tunnel.route_list.length : 0) + " routes through " + tunnel.dev,
        "routes": (tunnel.route_list || []).map(function (r) {
          return single ? r.dst : route(r);
        })
      };
    }
    return null;
  }

  // --- scans: who else is on the network, and what is near over Bluetooth ---------------
  // Both are Scans' (shell/Commons/Scans.qml), shared with the network panel. Nothing scans
  // by itself; the buttons do.
  readonly property var scan: Scans.network
  readonly property var blue: Scans.bluetooth

  // Nearness for the radar, 0 in the middle to 1 at the edge, on a log scale: 1 ms and
  // 10 ms are as far apart as 10 ms and 100 ms. What answered stays inside 0.85, so the
  // outer ring is left to what did not, and the two never sit on top of each other.
  function nearMs(ms) {
    return Math.min(0.85, 0.85 * Math.log(ms + 1) / Math.log(1001));
  }
  function nearMetres(m) {
    return Math.min(0.85, 0.85 * Math.log(m + 1) / Math.log(41));
  }

  function deviceName(d) {
    if (d.me)
      return "This machine" + (scan && scan.link && d.ip !== scan.link.address ? " (its other link)" : "");
    if (d.gateway)
      return d.name || "Router";
    return d.name || d.host || d.rdns || (d.vendor && d.vendor !== "private address" ? d.vendor : d.ip);
  }

  readonly property var netPoints: {
    if (!scan || !scan.devices)
      return [];
    return scan.devices.filter(function (d) {
      return !d.me;
    }).map(function (d) {
      return {
        "key": d.mac || d.ip,
        "label": page.deviceName(d),
        "near": d.ms !== null && d.ms !== undefined ? page.nearMs(d.ms) : 1,
        "ring": d.ms === null || d.ms === undefined,
        "tone": d.gateway ? page.placeTone : d.private ? Color.caution : d.vendor ? Color.popupAccent : Color.popupText
      };
    });
  }

  readonly property var btPoints: {
    if (!blue || !blue.devices)
      return [];
    return blue.devices.map(function (d) {
      return {
        "key": d.address,
        "label": d.name || d.doing || d.maker || (d.random ? "random address" : d.address),
        "near": d.metres !== null && d.metres !== undefined ? page.nearMetres(d.metres) : 1,
        "ring": !d.near,
        "tone": d.connected ? Color.good : d.paired ? Color.popupAccent : d.random ? Color.caution : Color.popupText
      };
    });
  }

  function ago(stamp) {
    if (!stamp)
      return "";
    var s = Math.max(0, Math.round(Date.now() / 1000 - stamp));
    return s < 90 ? "just now" : s < 5400 ? Math.round(s / 60) + " min ago" : s < 129600 ? Math.round(s / 3600) + " h ago" : Math.round(s / 86400) + " days ago";
  }

  function linkWords(link) {
    if (!link)
      return "no link";
    if (link.kind === "wifi")
      return "Wi-Fi" + (link.signal ? "  ·  " + link.signal + "%" : "") + (link.band ? "  ·  " + link.band : "");
    return "cable  ·  " + link.dev;
  }

  // A box on the path: this machine, the router, the internet, the tunnel.
  component Stop: Rectangle {
    id: stop

    property string icon: ""
    property string name: ""
    property string detail: ""
    property string extra: ""
    property color tone: Color.popupText
    property bool reached: true
    // Which details a click opens; "" for a box with nothing more to say.
    property string key: ""
    readonly property bool picked: key !== "" && page.chosen === key

    radius: Style.radius
    color: picked ? Qt.rgba(tone.r, tone.g, tone.b, 0.14) : press.containsMouse && key !== "" ? Color.popupHover : Color.popupBackground
    border.width: picked ? 3 : reached ? 2 : 1
    border.color: reached || picked ? tone : Color.popupBorder
    opacity: reached || picked ? 1 : 0.55

    MouseArea {
      id: press

      anchors.fill: parent
      enabled: stop.key !== ""
      hoverEnabled: true
      cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
      onClicked: page.pick(stop.key)
    }

    Column {
      anchors.centerIn: parent
      width: parent.width - Style.popupPadding * 2
      spacing: 4

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: stop.icon
        color: stop.reached ? stop.tone : Color.popupMuted
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSize + 18
      }
      Text {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: stop.name
        textFormat: Text.PlainText
        color: Color.popupText
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSize + 3
        font.weight: Style.barLabelWeight
        elide: Text.ElideRight
      }
      Text {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: stop.detail
        textFormat: Text.PlainText
        color: Color.popupMuted
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSize
        elide: Text.ElideRight
      }
      Text {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        visible: text !== ""
        text: stop.extra
        textFormat: Text.PlainText
        color: Color.popupMuted
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSize - 1
        elide: Text.ElideRight
      }
    }
  }

  // The stretch between two boxes, with what it is written over it. Something travels
  // along it while it carries traffic, and only while the page is being looked at.
  component Stretch: Item {
    id: stretch

    property string label: ""
    property color tone: Color.popupAccent
    property bool carries: true

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: line.top
      anchors.bottomMargin: 6
      width: parent.width - 8
      horizontalAlignment: Text.AlignHCenter
      text: stretch.label
      textFormat: Text.PlainText
      color: stretch.carries ? Color.popupText : Color.popupMuted
      font.family: Style.fontFamily
      font.pixelSize: Style.fontSize - 1
      elide: Text.ElideRight
    }
    Rectangle {
      id: line

      anchors.verticalCenter: parent.verticalCenter
      width: parent.width
      height: 3
      radius: 1.5
      color: stretch.carries ? stretch.tone : Color.popupBorder
      opacity: stretch.carries ? 0.55 : 1
    }
    Rectangle {
      id: packet

      visible: stretch.carries && page.active && page.heading === "network"
      anchors.verticalCenter: parent.verticalCenter
      width: 10
      height: 10
      radius: 5
      color: stretch.tone

      NumberAnimation on x {
        running: packet.visible
        loops: Animation.Infinite
        from: 0
        to: Math.max(0, stretch.width - packet.width)
        duration: Style.motionBreath
        easing.type: Easing.InOutSine
      }
    }
  }

  // A button on a card: start a scan. Busy, it says so and cannot be pressed again.
  component Act: Rectangle {
    id: act

    property string text: ""
    property bool busy: false
    property color tone: Color.popupAccent
    signal pressed

    implicitWidth: actLabel.implicitWidth + 28
    implicitHeight: actLabel.implicitHeight + 12
    radius: height / 2
    color: busy ? Qt.rgba(tone.r, tone.g, tone.b, 0.12) : actArea.containsMouse ? Qt.rgba(tone.r, tone.g, tone.b, 0.22) : "transparent"
    border.width: 1
    border.color: tone

    Text {
      id: actLabel

      anchors.centerIn: parent
      text: act.busy ? "Scanning…" : act.text
      textFormat: Text.PlainText
      color: act.tone
      font.family: Style.fontFamily
      font.pixelSize: Style.fontSize
    }
    MouseArea {
      id: actArea

      anchors.fill: parent
      hoverEnabled: true
      enabled: !act.busy
      cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
      onClicked: act.pressed()
    }
  }

  // One device in a list: what it is called, and everything else known of it underneath.
  component DeviceLine: Column {
    id: line

    property string title: ""
    property string detail: ""
    property string more: ""
    property color tone: Color.popupText
    property bool lit: false

    bottomPadding: 6

    Text {
      width: parent.width
      text: line.title
      textFormat: Text.PlainText
      color: line.lit ? Color.popupText : line.tone
      font.family: Style.fontFamily
      font.pixelSize: Style.fontSize + 1
      font.weight: Style.barLabelWeight
      font.underline: line.lit
      elide: Text.ElideRight
    }
    Quiet {
      width: parent.width
      text: line.detail
    }
    Quiet {
      width: parent.width
      visible: line.more !== ""
      text: line.more
    }
  }

  // The headings, as a second and smaller row of tabs.
  Row {
    spacing: Style.sectionSpacing

    Choice {
      options: page.headings.map(function (name) {
        return {
          id: name,
          label: page.titles[name]
        };
      })
      chosen: page.heading
      textSize: Style.fontSize + 1
      onPicked: id => page.choose(id)
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      leftPadding: Style.sectionSpacing
      text: "↑ ↓ to change"
      color: Color.popupBorder
      font.family: Style.fontFamily
      font.pixelSize: Style.fontSize - 2
    }
  }

  function tone(state) {
    return state === "healthy" ? Color.good : state === "degraded" ? Color.popupUrgent : state === "updating" ? Color.popupAccent : Color.popupMuted;
  }

  function words(cluster) {
    if (cluster.state === "signed-out")
      return "no token  ·  ocl " + cluster.name;
    if (cluster.state === "degraded")
      return (cluster.nodes - cluster.ready) + " of " + cluster.nodes + " nodes not ready";
    if (cluster.state === "updating")
      return "updating  ·  " + cluster.ready + " of " + cluster.nodes + " nodes ready";
    return cluster.ready + " of " + cluster.nodes + " nodes ready";
  }

  Unconnected {
    visible: page.heading === "clusters" && !!page.info && page.info.connected === false
    how: page.info && page.info.how ? page.info.how : []
  }

  GridLayout {
    visible: page.heading === "clusters"
    Layout.fillWidth: true
    columns: page.width > 1500 ? 4 : (page.width > 900 ? 3 : 2)
    columnSpacing: Style.overviewSpacing
    rowSpacing: Style.overviewSpacing

    Card {
      order: 0
      appear: page.active
      Layout.columnSpan: parent.columns
      icon: "\u{f048b}"
      title: "Clusters"
      tone: page.info && page.info.trouble > 0 ? Color.popupUrgent : Color.good

      Row {
        spacing: Style.overviewSpacing * 1.5
        topPadding: 6
        bottomPadding: 6

        Figure {
          appear: page.active
          value: page.info ? page.info.clusters.length : 0
          label: "known"
        }
        Figure {
          appear: page.active
          value: page.info ? page.info.signed_in : 0
          label: "signed in"
          tone: Color.popupAccent
        }
        Figure {
          appear: page.active
          value: page.info ? page.info.trouble : 0
          label: "in trouble"
          tone: page.info && page.info.trouble > 0 ? Color.popupUrgent : Color.good
        }
      }
    }

    Repeater {
      model: page.info ? page.info.clusters : []

      delegate: Card {
        id: tile

        required property var modelData
        required property int index

        order: index + 1
        appear: page.active
        icon: "\u{f048b}"
        title: modelData.name
        figure: modelData.version || ""
        tone: page.tone(modelData.state)

        Row {
          spacing: Style.sectionSpacing
          topPadding: 6

          // The light. It breathes when something is wrong, and only then: on a page of
          // steady lights the one that moves is the one to look at.
          Rectangle {
            id: light

            anchors.verticalCenter: parent.verticalCenter
            width: 12
            height: 12
            radius: 6
            color: tile.tone

            SequentialAnimation on opacity {
              running: tile.modelData.state === "degraded" && page.active
              loops: Animation.Infinite
              onRunningChanged: if (!running)
                light.opacity = 1

              NumberAnimation {
                to: 0.25
                duration: Style.motionBreath / 2
                easing.type: Easing.InOutSine
              }
              NumberAnimation {
                to: 1
                duration: Style.motionBreath / 2
                easing.type: Easing.InOutSine
              }
            }
          }
          Text {
            text: tile.modelData.state.replace("-", " ")
            color: tile.tone
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSize + 2
            font.weight: Style.barLabelWeight
          }
        }
        Quiet {
          text: page.words(tile.modelData)
        }
        // How many of its nodes are ready, as a bar that fills.
        Rectangle {
          visible: (tile.modelData.nodes || 0) > 0
          width: parent.width
          height: 5
          radius: 2.5
          color: Color.popupBorder

          Rectangle {
            height: parent.height
            radius: parent.radius
            color: tile.tone
            width: page.active ? parent.width * (tile.modelData.ready || 0) / Math.max(1, tile.modelData.nodes || 1) : 0

            Behavior on width {
              NumberAnimation {
                duration: 700
                easing.type: Easing.OutCubic
              }
            }
          }
        }
      }
    }
  }

  // --- network ---------------------------------------------------------------------------
  Rectangle {
    id: picture

    readonly property real box: Math.max(170, Math.min(300, width * 0.22))
    readonly property real tall: 150
    readonly property real gap: 70

    visible: page.heading === "network"
    Layout.fillWidth: true
    implicitHeight: Style.popupPadding * 4 + whereabouts.implicitHeight + tall + (page.tunnel ? gap + tall : 0)
    radius: Style.radius
    color: Color.popupBackground
    border.width: 1
    border.color: Color.popupBorder

    Column {
      id: whereabouts

      x: Style.popupPadding * 2
      y: Style.popupPadding * 1.5
      spacing: 2

      Text {
        text: page.net && page.net.place ? page.net.place.name : "Looking…"
        textFormat: Text.PlainText
        color: page.placeTone
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSize + 14
        font.weight: Style.barLabelWeight
      }
      Text {
        text: !page.net ? "" : (page.net.place.kind === "home" ? "home" : page.net.place.kind === "work" ? "work" : page.net.place.kind === "away" ? "away" : page.net.place.kind === "none" ? "offline" : "a network without a name of yours") + "  ·  known by " + page.net.place.why + "  ·  click a box for its details"
        textFormat: Text.PlainText
        color: Color.popupMuted
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSize
      }
    }

    Item {
      id: path

      x: Style.popupPadding * 2
      y: whereabouts.y + whereabouts.implicitHeight + Style.popupPadding * 1.5
      width: parent.width - Style.popupPadding * 4
      height: picture.tall + (page.tunnel ? picture.gap + picture.tall : 0)

      Stop {
        id: machine

        width: picture.box
        height: picture.tall
        key: "machine"
        icon: "\u{f0322}"
        name: "This machine"
        detail: page.link && page.link.address ? page.link.address : "no address"
        extra: page.link ? page.link.dev : ""
        tone: page.placeTone
        reached: !!page.link
      }
      Stretch {
        x: machine.x + machine.width
        width: router.x - x
        height: picture.tall
        label: page.link ? (page.link.kind === "wifi" ? (page.link.ssid || page.link.connection) : page.link.connection) + "\n" + page.linkWords(page.link) : "not connected"
        tone: page.placeTone
        carries: !!page.link
      }
      Stop {
        id: router

        x: (path.width - width) / 2
        width: picture.box
        height: picture.tall
        key: "router"
        icon: "\u{f0469}"
        name: "Router"
        detail: page.net && page.net.router.address ? page.net.router.address : "none"
        extra: !page.net || !page.net.router.address ? "" : page.net.router.ms !== null && page.net.router.ms !== undefined ? "answers in " + page.net.router.ms + " ms" : "does not answer a ping"
        tone: page.placeTone
        reached: !!page.net && !!page.net.router.address
      }
      Stretch {
        x: router.x + router.width
        width: internet.x - x
        height: picture.tall
        label: !page.net ? "" : page.tunnel && page.tunnel.all ? "everything goes through the VPN" : page.online ? "the way out" : page.net.online === "portal" ? "a login page is in the way" : "no way out"
        tone: page.online ? Color.good : Color.popupUrgent
        carries: page.online && !(page.tunnel && page.tunnel.all)
      }
      Stop {
        id: internet

        x: path.width - width
        width: picture.box
        height: picture.tall
        key: "internet"
        icon: "\u{f01e7}"
        name: "Internet"
        detail: !page.net ? "" : page.online ? "reachable" : page.net.online === "portal" ? "behind a login page" : "not reachable"
        extra: page.net && page.net.dns.length > 0 ? "names at " + page.net.dns[0] : ""
        tone: page.online ? Color.good : Color.popupUrgent
        reached: page.online
      }

      // The tunnel leaves from this machine, under the rest: down, and then across.
      Rectangle {
        visible: !!page.tunnel
        x: machine.x + machine.width / 2 - 1.5
        y: machine.height
        width: 3
        height: picture.gap + picture.tall / 2
        radius: 1.5
        color: Color.popupAccent
        opacity: 0.55
      }
      Stretch {
        visible: !!page.tunnel
        x: machine.x + machine.width / 2
        y: picture.tall + picture.gap
        width: vpn.x - x
        height: picture.tall
        label: "encrypted tunnel"
        tone: Color.popupAccent
      }
      Stop {
        id: vpn

        visible: !!page.tunnel
        x: router.x
        y: picture.tall + picture.gap
        width: picture.box
        height: picture.tall
        key: "vpn"
        icon: "\u{f099d}"
        name: page.tunnel ? "VPN " + page.tunnel.connection : ""
        detail: page.tunnel ? (page.tunnel.address || page.tunnel.dev) : ""
        extra: page.tunnel ? page.tunnel.dev : ""
        tone: Color.popupAccent
      }
      Stretch {
        visible: !!page.tunnel
        x: vpn.x + vpn.width
        y: vpn.y
        width: beyond.x - x
        height: picture.tall
        label: page.tunnel ? (page.tunnel.all ? "all traffic" : page.tunnel.routes + (page.tunnel.routes === 1 ? " network" : " networks")) : ""
        tone: Color.popupAccent
      }
      Stop {
        id: beyond

        visible: !!page.tunnel
        x: internet.x
        y: vpn.y
        width: picture.box
        height: picture.tall
        key: "vpn"
        icon: "\u{f0991}"
        name: "Behind the VPN"
        detail: page.tunnel && page.tunnel.reaches.length > 0 ? page.tunnel.reaches.slice(0, 2).join("  ") : ""
        extra: page.tunnel && page.tunnel.reaches.length > 2 ? "and " + (page.tunnel.routes - 2) + " more" : ""
        tone: Color.popupAccent
      }
    }
  }

  // What the open box has to say. The routes are laid out in as many columns as fit, in
  // address order, so eighty networks behind a VPN are a page to scan, not a list to scroll.
  Card {
    id: detailCard

    visible: page.heading === "network" && page.details !== null
    appear: visible
    Layout.fillWidth: true
    icon: page.details ? page.details.icon : ""
    title: page.details ? page.details.title : ""
    tone: page.details ? page.details.tone : Color.popupText
    figure: page.details && page.details.routes.length ? String(page.details.routes.length) : ""

    // While the screen is shared the box still opens, but says why it shows nothing: the
    // addresses and routes are a map of a network, and a call is no place to hand it out.
    Quiet {
      visible: Sharing.active
      text: "Hidden while the screen is shared. Stop sharing to see the addresses and routes."
    }

    Repeater {
      model: page.details && !Sharing.active ? page.details.facts : []

      delegate: Row {
        id: factRow

        required property var modelData
        spacing: Style.sectionSpacing

        Text {
          width: 170
          text: factRow.modelData[0]
          textFormat: Text.PlainText
          color: Color.popupMuted
          font.family: Style.fontFamily
          font.pixelSize: Style.fontSize
        }
        Text {
          width: detailCard.width - 170 - Style.sectionSpacing - Style.popupPadding * 2
          text: factRow.modelData[1]
          textFormat: Text.PlainText
          color: Color.popupText
          font.family: Style.fontFamily
          font.pixelSize: Style.fontSize + 1
          wrapMode: Text.WrapAnywhere
        }
      }
    }

    Text {
      visible: page.details !== null && page.details.routesTitle !== "" && !Sharing.active
      topPadding: Style.popupPadding
      bottomPadding: 4
      text: page.details ? page.details.routesTitle : ""
      textFormat: Text.PlainText
      color: Color.popupMuted
      font.family: Style.fontFamily
      font.pixelSize: Style.fontSize - 1
      font.bold: true
      font.letterSpacing: 1
      font.capitalization: Font.AllUppercase
    }

    Grid {
      id: routeGrid

      // As wide as the longest line, so none is cut short; the font is monospaced.
      readonly property real cell: {
        var longest = 0;
        var routes = page.details ? page.details.routes : [];
        for (var i = 0; i < routes.length; i++)
          longest = Math.max(longest, routes[i].length);
        return Math.max(160, longest * Style.fontSize * 0.62 + columnSpacing + 8);
      }
      width: detailCard.width - Style.popupPadding * 2
      columns: Math.max(1, Math.floor(width / cell))
      columnSpacing: Style.sectionSpacing
      rowSpacing: 2
      flow: Grid.TopToBottom
      rows: page.details && !Sharing.active ? Math.ceil(page.details.routes.length / columns) : 0

      Repeater {
        model: page.details && !Sharing.active ? page.details.routes : []

        delegate: Text {
          required property string modelData

          width: routeGrid.cell - routeGrid.columnSpacing
          text: modelData
          textFormat: Text.PlainText
          color: Color.popupText
          font.family: Style.fontFamily
          font.pixelSize: Style.fontSize
          elide: Text.ElideRight
        }
      }
    }

    Quiet {
      text: "Click the box again to close this."
    }
  }

  GridLayout {
    visible: page.heading === "network"
    Layout.fillWidth: true
    columns: page.width > 1100 ? 2 : 1
    columnSpacing: Style.overviewSpacing
    rowSpacing: Style.overviewSpacing

    Card {
      order: 0
      appear: page.active && page.heading === "network"
      Layout.alignment: Qt.AlignTop
      icon: "\u{f0317}"
      title: "In words"
      tone: page.placeTone

      Repeater {
        model: page.net ? page.net.lines : []

        delegate: Text {
          required property string modelData

          width: parent ? parent.width : 0
          text: modelData
          textFormat: Text.PlainText
          color: Color.popupText
          font.family: Style.fontFamily
          font.pixelSize: Style.fontSize + 1
          wrapMode: Text.WordWrap
          bottomPadding: 4
        }
      }
      Quiet {
        visible: !page.net
        text: "Looking at the network…"
      }
    }

    Card {
      order: 1
      appear: page.active && page.heading === "network"
      Layout.alignment: Qt.AlignTop
      icon: "\u{f05a9}"
      title: "Connections"
      figure: page.net ? String(page.net.links.length + page.net.vpn.length) : ""

      Repeater {
        model: page.net ? page.net.links.concat(page.net.vpn) : []

        delegate: Column {
          id: row

          required property var modelData

          width: parent ? parent.width : 0
          bottomPadding: 6

          Text {
            width: parent.width
            text: row.modelData.connection + (row.modelData.kind === "vpn" ? "  ·  VPN" : row.modelData.primary ? "  ·  the way out" : "")
            textFormat: Text.PlainText
            color: row.modelData.kind === "vpn" ? Color.popupAccent : row.modelData.primary ? page.placeTone : Color.popupText
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSize + 1
            font.weight: Style.barLabelWeight
            elide: Text.ElideRight
          }
          Quiet {
            text: (row.modelData.kind === "vpn" ? "tunnel" : page.linkWords(row.modelData)) + "  ·  " + row.modelData.dev + "  ·  " + (row.modelData.address || "no address")
          }
        }
      }
      Quiet {
        visible: !!page.net && page.net.links.length + page.net.vpn.length === 0
        text: "Nothing is connected."
      }
      Quiet {
        visible: !!page.net && page.net.domains.length > 0
        text: page.net ? "Search domains: " + page.net.domains.join(", ") : ""
      }
    }
  }

  // --- network: who else is on it, and the Wi-Fi around ---------------------------------
  Card {
    id: netCard

    visible: page.heading === "network"
    appear: page.active && page.heading === "network"
    Layout.fillWidth: true
    order: 2
    icon: "\u{f0f86}"
    title: "Devices on this network"
    figure: page.scan && page.scan.devices ? String(page.scan.devices.length) : ""
    tone: page.placeTone

    Row {
      spacing: Style.sectionSpacing

      Act {
        text: page.scan ? "Scan again" : "Scan"
        busy: Scans.scanningNetwork
        onPressed: Scans.scanNetwork(false)
      }
      // Only offered where a scan stayed quiet: a network that is not marked as yours.
      Act {
        visible: !!page.scan && !page.scan.swept && !!page.scan.link && !Scans.scanningNetwork
        text: "Ping every address"
        tone: Color.caution
        onPressed: Scans.scanNetwork(true)
      }
      Quiet {
        width: implicitWidth
        anchors.verticalCenter: parent.verticalCenter
        text: !page.scan ? "Nothing scanned yet. A scan touches only the link this machine is on, never the VPN." : (page.scan.swept ? "Pinged " + (page.scan.scope || "") + "  ·  " + page.scan.mode : "Quiet: nothing was sent") + "  ·  " + page.ago(page.scan.checked) + (page.scan.took ? "  ·  took " + page.scan.took + " s" : "")
      }
    }

    Quiet {
      visible: !!page.scan && !page.scan.swept && page.scan.why !== ""
      width: parent.width
      wrapMode: Text.WordWrap
      color: Color.caution
      text: page.scan ? page.scan.why + " Mark it as home in ~/.config/desktop/networks.conf to sweep it by default." : ""
    }

    Quiet {
      visible: Sharing.active
      text: "Hidden while the screen is shared: names, addresses and makers of the devices here."
    }

    Item {
      visible: !!page.scan && !Sharing.active
      width: parent.width
      height: Math.max(netRadar.height, netList.implicitHeight)

      Radar {
        id: netRadar

        width: Math.min(400, parent.width * 0.4)
        height: 340
        points: page.netPoints
        tone: page.placeTone
        rings: [
          {
            "at": page.nearMs(10),
            "label": "10 ms"
          },
          {
            "at": page.nearMs(100),
            "label": "100 ms"
          },
          {
            "at": page.nearMs(1000),
            "label": "1 s"
          },
          {
            "at": 1,
            "label": "quiet"
          }
        ]
      }

      // Two columns where there is room for them, so a busy network does not run a long
      // way down the page beside a radar that stopped long before.
      Grid {
        id: netList

        anchors.left: netRadar.right
        anchors.leftMargin: Style.sectionSpacing * 2
        anchors.right: parent.right
        columns: width > 900 ? 2 : 1
        columnSpacing: Style.sectionSpacing * 2
        readonly property real cell: (width - columnSpacing * (columns - 1)) / columns

        Repeater {
          model: page.scan && page.scan.devices ? page.scan.devices : []

          delegate: DeviceLine {
            required property var modelData

            width: netList.cell

            title: page.deviceName(modelData) + (modelData.gateway && page.deviceName(modelData) !== "Router" ? "  ·  router" : "") + (modelData.private ? "  ·  private address" : "")
            detail: modelData.ip + "  ·  " + (modelData.mac || "no MAC") + (modelData.vendor && modelData.vendor !== "private address" ? "  ·  " + modelData.vendor : "") + (modelData.me ? "" : "  ·  " + (modelData.ms !== null && modelData.ms !== undefined ? modelData.ms + " ms" : page.scan.swept ? "no answer to ping" : "not pinged"))
            more: [modelData.host && modelData.host !== page.deviceName(modelData) ? modelData.host : "", modelData.rdns && modelData.rdns !== modelData.host ? modelData.rdns : "", modelData.services.length ? "offers " + modelData.services.join(", ") : "", modelData.me ? "" : "seen by " + modelData.found.join(", ")].filter(function (x) {
              return x !== "";
            }).join("  ·  ")
            tone: modelData.me ? page.placeTone : modelData.private ? Color.caution : Color.popupText
            lit: netRadar.hovered !== "" && netRadar.hovered === (modelData.mac || modelData.ip)
          }
        }
      }
    }
  }

  Card {
    visible: page.heading === "network" && !!page.scan && !!page.scan.wifi && page.scan.wifi.length > 0
    appear: page.active && page.heading === "network"
    Layout.fillWidth: true
    order: 3
    icon: "\u{f05a9}"
    title: "Wi-Fi around"
    figure: page.scan && page.scan.wifi ? String(page.scan.wifi.length) : ""

    Quiet {
      visible: Sharing.active
      text: "Hidden while the screen is shared: the names and addresses of the networks around."
    }

    // A bar for each network's signal, and what is known of it beside it, in as many
    // columns as fit: one list rather than a chart and the same networks again under it.
    Grid {
      id: wifiList

      width: parent.width
      columns: Math.max(1, Math.floor((width + columnSpacing) / (560 + columnSpacing)))
      columnSpacing: Style.sectionSpacing * 2
      rowSpacing: 4
      readonly property real cell: (width - columnSpacing * (columns - 1)) / columns

      Repeater {
        model: page.scan && page.scan.wifi && !Sharing.active ? page.scan.wifi.slice(0, 18) : []

        delegate: Row {
          id: air

          required property var modelData
          readonly property color tone: modelData.current ? page.placeTone : Color.popupMuted

          width: wifiList.cell
          spacing: Style.sectionSpacing

          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 80
            height: 6
            radius: 3
            color: Qt.rgba(Color.popupText.r, Color.popupText.g, Color.popupText.b, 0.08)

            Rectangle {
              width: parent.width * Math.max(0.04, air.modelData.signal / 100)
              height: parent.height
              radius: parent.radius
              color: air.modelData.current ? page.placeTone : Color.popupAccent
              opacity: air.modelData.current ? 1 : 0.55
            }
          }
          Text {
            width: air.width - 80 - air.spacing
            anchors.verticalCenter: parent.verticalCenter
            text: air.modelData.signal + "%  " + air.modelData.ssid + (air.modelData.current ? "  (this one)" : "") + "  ·  " + air.modelData.band + " ch " + air.modelData.channel + "  ·  " + air.modelData.security + "  ·  " + air.modelData.bssid
            textFormat: Text.PlainText
            color: air.tone
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSize
            elide: Text.ElideRight
          }
        }
      }
    }
  }

  // --- bluetooth: what is near ----------------------------------------------------------
  Card {
    id: btCard

    visible: page.heading === "bluetooth"
    appear: page.active && page.heading === "bluetooth"
    Layout.fillWidth: true
    order: 0
    icon: "\u{f00af}"
    title: "Bluetooth near"
    figure: page.blue && page.blue.devices ? String(page.blue.devices.filter(function (d) {
      return d.near;
    }).length) : ""
    tone: Color.popupAccent

    Row {
      spacing: Style.sectionSpacing

      Act {
        text: page.blue ? "Listen again" : "Listen"
        busy: Scans.scanningBluetooth
        onPressed: Scans.scanBluetooth()
      }
      Quiet {
        width: implicitWidth
        anchors.verticalCenter: parent.verticalCenter
        text: !page.blue ? "Twelve seconds of listening for what devices announce; nothing is asked of them." : page.blue.powered === false ? "Bluetooth is off. It is left off: turn it on to listen." : "Listened " + page.blue.seconds + " s  ·  " + page.ago(page.blue.checked) + "  ·  the distance is a guess from the signal, and walls shorten it"
      }
    }

    Quiet {
      visible: Sharing.active
      text: "Hidden while the screen is shared: names and addresses of the devices near."
    }

    Item {
      visible: !!page.blue && !!page.blue.devices && page.blue.devices.length > 0 && !Sharing.active
      width: parent.width
      height: Math.max(btRadar.height, btList.implicitHeight)

      Radar {
        id: btRadar

        width: Math.min(420, parent.width * 0.4)
        height: 380
        points: page.btPoints
        rings: [
          {
            "at": page.nearMetres(1),
            "label": "1 m"
          },
          {
            "at": page.nearMetres(3),
            "label": "3 m"
          },
          {
            "at": page.nearMetres(10),
            "label": "10 m"
          },
          {
            "at": 1,
            "label": "known, not heard"
          }
        ]
      }

      // Two columns where there is room for them, so a busy network does not run a long
      // way down the page beside a radar that stopped long before.
      Grid {
        id: btList

        anchors.left: btRadar.right
        anchors.leftMargin: Style.sectionSpacing * 2
        anchors.right: parent.right
        columns: width > 900 ? 2 : 1
        columnSpacing: Style.sectionSpacing * 2
        readonly property real cell: (width - columnSpacing * (columns - 1)) / columns

        Repeater {
          model: page.blue && page.blue.devices ? page.blue.devices : []

          delegate: DeviceLine {
            required property var modelData

            width: btList.cell

            title: (modelData.name || modelData.doing || modelData.maker || "Nameless") + (modelData.connected ? "  ·  connected" : modelData.paired ? "  ·  paired" : "")
            detail: (modelData.near ? "about " + modelData.metres + " m  ·  " + modelData.rssi + " dBm" : "not heard this time") + "  ·  " + modelData.kind + (modelData.maker ? "  ·  " + modelData.maker : "") + (modelData.battery !== null && modelData.battery !== undefined ? "  ·  battery " + modelData.battery + "%" : "")
            more: [modelData.address + (modelData.random ? " (random, changes)" : ""), modelData.doing && modelData.name ? modelData.doing : "", modelData.services.length ? modelData.services.join(", ") : ""].filter(function (x) {
              return x !== "";
            }).join("  ·  ")
            tone: modelData.connected ? Color.good : modelData.paired ? Color.popupAccent : modelData.near ? Color.popupText : Color.popupMuted
            lit: btRadar.hovered === modelData.address
          }
        }
      }
    }
  }
}
