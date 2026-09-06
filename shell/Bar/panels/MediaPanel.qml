import QtQuick
import qs.Commons
import qs.Ui

// Media panel: what is playing, where it is, and the transport.
//
// Everything reads through the Media singleton, so clicking a player here also changes
// what the bar widget shows.
Popup {
  id: root

  readonly property string panelId: "media"

  readonly property var player: Media.active
  readonly property var players: Media.players

  readonly property bool seekable: !!player && player.lengthSupported && player.positionSupported

  // MPRIS does not push position while a track plays -- it is read on demand -- so the
  // progress bar only moves if something asks. Re-emitting the notify signal is what
  // makes the bindings below re-read it, and only while the panel is open.
  Timer {
    interval: 1000
    repeat: true
    running: root.visible && !!root.player && root.player.isPlaying
    onTriggered: root.player.positionChanged()
  }

  contentWidth: Style.popupWidth
  contentHeight: column.implicitHeight + Style.popupPadding * 2

  Column {
    id: column

    width: parent.width
    spacing: 2

    PanelSection {
      title: "Now playing"
      value: root.player ? root.player.identity : "nothing"
    }

    // Track. Three lines that collapse individually, so a podcast with no album does
    // not leave a gap where the album would be.
    Item {
      width: parent.width
      height: trackLines.implicitHeight + 8
      visible: !!root.player

      Column {
        id: trackLines

        anchors.left: parent.left
        anchors.leftMargin: 6
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Text {
          width: parent.width
          visible: !!root.player && root.player.trackTitle !== ""
          text: root.player ? root.player.trackTitle : ""
          textFormat: Text.PlainText
          color: Color.popupText
          font.family: Style.fontFamily
          font.pixelSize: Style.fontSize
          font.bold: true
          elide: Text.ElideRight
        }

        Text {
          width: parent.width
          visible: !!root.player && root.player.trackArtist !== ""
          text: root.player ? root.player.trackArtist : ""
          textFormat: Text.PlainText
          color: Color.popupText
          font.family: Style.fontFamily
          font.pixelSize: Style.fontSize - 1
          elide: Text.ElideRight
        }

        Text {
          width: parent.width
          visible: !!root.player && root.player.trackAlbum !== ""
          text: root.player ? root.player.trackAlbum : ""
          textFormat: Text.PlainText
          color: Color.popupMuted
          font.family: Style.fontFamily
          font.pixelSize: Style.fontSize - 2
          elide: Text.ElideRight
        }
      }
    }

    // Progress. Hidden rather than disabled for a stream, where position and length
    // are both meaningless.
    Item {
      width: parent.width
      height: visible ? 30 : 0
      visible: root.seekable && root.player.length > 0

      Text {
        id: elapsed

        anchors.left: parent.left
        anchors.leftMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        text: root.player ? Media.time(root.player.position) : ""
        color: Color.popupMuted
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSize - 2
      }

      Text {
        id: total

        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        text: root.player ? Media.time(root.player.length) : ""
        color: Color.popupMuted
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSize - 2
      }

      PanelSlider {
        anchors.left: elapsed.right
        anchors.leftMargin: 10
        anchors.right: total.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        enabled: !!root.player && root.player.canSeek
        value: (root.player && root.player.length > 0) ? root.player.position / root.player.length : 0
        onMoved: fraction => {
          if (root.player && root.player.canSeek)
            root.player.position = fraction * root.player.length;
        }
      }
    }

    // Transport.
    Item {
      width: parent.width
      height: 34
      visible: !!root.player

      Row {
        anchors.centerIn: parent
        spacing: 24

        TransportButton {
          glyph: ""
          active: !!root.player && root.player.canGoPrevious
          onTriggered: root.player.previous()
        }

        TransportButton {
          glyph: (root.player && root.player.isPlaying) ? "" : ""
          active: !!root.player && root.player.canTogglePlaying
          onTriggered: root.player.togglePlaying()
        }

        TransportButton {
          glyph: ""
          active: !!root.player && root.player.canGoNext
          onTriggered: root.player.next()
        }
      }
    }

    PanelSection {
      title: "Volume"
      value: (root.player && root.player.volumeSupported) ? Math.round(root.player.volume * 100) + "%" : ""
      rule: true
      visible: !!root.player && root.player.volumeSupported
    }

    Item {
      width: parent.width
      height: visible ? 26 : 0
      visible: !!root.player && root.player.volumeSupported

      PanelSlider {
        anchors.left: parent.left
        anchors.leftMargin: 6
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        value: root.player ? root.player.volume : 0
        onMoved: v => {
          if (root.player)
            root.player.volume = v;
        }
      }
    }

    // Only worth a list when there is a choice to make.
    PanelSection {
      title: "Players"
      rule: true
      visible: root.players.length > 1
    }

    Repeater {
      model: root.players.length > 1 ? root.players : []

      delegate: PanelRow {
        required property var modelData

        icon: modelData.isPlaying ? "" : ""
        label: modelData.identity || modelData.dbusName
        sublabel: Media.label(modelData)
        active: root.player && modelData.dbusName === root.player.dbusName
        onClicked: Media.select(modelData)
      }
    }
  }

  // A glyph that behaves like a button: dimmed when the player cannot do it, and with
  // a hit area larger than the glyph, which is only a dozen pixels across.
  component TransportButton: Item {
    id: button

    property string glyph: ""
    property bool active: false

    signal triggered

    implicitWidth: label.implicitWidth + 16
    implicitHeight: 26

    Text {
      id: label

      anchors.centerIn: parent
      text: button.glyph
      color: mouse.containsMouse && button.active ? Color.popupAccent : Color.popupText
      opacity: button.active ? 1.0 : 0.35
      font.family: Style.fontFamily
      font.pixelSize: Style.iconSize
    }

    MouseArea {
      id: mouse

      anchors.fill: parent
      hoverEnabled: true
      enabled: button.active
      cursorShape: Qt.PointingHandCursor
      onClicked: button.triggered()
    }
  }
}
