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

  readonly property var headings: ["clusters", "network"]
  readonly property var titles: ({
      "clusters": "Clusters",
      "network": "Network"
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

    radius: Style.radius
    color: Color.popupBackground
    border.width: reached ? 2 : 1
    border.color: reached ? tone : Color.popupBorder
    opacity: reached ? 1 : 0.55

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
        text: !page.net ? "" : (page.net.place.kind === "home" ? "home" : page.net.place.kind === "work" ? "work" : page.net.place.kind === "away" ? "away" : page.net.place.kind === "none" ? "offline" : "a network without a name of yours") + "  ·  known by " + page.net.place.why
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
        icon: "\u{f0991}"
        name: "Behind the VPN"
        detail: page.tunnel && page.tunnel.reaches.length > 0 ? page.tunnel.reaches.slice(0, 2).join("  ") : ""
        extra: page.tunnel && page.tunnel.reaches.length > 2 ? "and " + (page.tunnel.routes - 2) + " more" : ""
        tone: Color.popupAccent
      }
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
}
