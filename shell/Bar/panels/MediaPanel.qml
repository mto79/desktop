import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Ui

// Media panel: what is playing, where it is, and the transport.
//
// Laid out like the battery panel, with the artwork as the big thing at the top: a cover
// is recognised before a title is read. Then the progress, the transport with shuffle
// and repeat where the player offers them, and the speaker it is coming out of --
// "where is the sound going" being the other half of "what is playing".
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

    // --- The cover, big, and what it is ----------------------------------------------
    Item {
      width: parent.width
      height: 104

      Rectangle {
        id: cover

        anchors.left: parent.left
        anchors.leftMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        width: 92
        height: 92
        radius: Style.radius
        color: Color.popupHover
        clip: true

        Image {
          id: art

          anchors.fill: parent
          source: root.player && root.player.trackArtUrl ? root.player.trackArtUrl : ""
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          // Browsers hand over a temp file that is gone by the next track; a failed
          // load falls back to the glyph rather than an empty square.
          visible: status === Image.Ready
        }

        Text {
          anchors.centerIn: parent
          visible: !art.visible
          text: "\u{f075a}"
          color: Color.popupMuted
          font.family: Style.fontFamily
          font.pixelSize: 40
        }
      }

      Column {
        anchors.left: cover.right
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3

        Text {
          width: parent.width
          text: {
            if (!root.player)
              return "NOTHING PLAYING";
            return (root.player.identity + "  ·  " + (root.player.isPlaying ? "playing" : "paused")).toUpperCase();
          }
          color: root.player && root.player.isPlaying ? Color.popupAccent : Color.popupMuted
          font.family: Style.fontFamily
          font.pixelSize: Style.fontSize - 3
          font.bold: true
          font.letterSpacing: 1
          elide: Text.ElideRight
        }

        Text {
          width: parent.width
          visible: !!root.player && root.player.trackTitle !== ""
          text: root.player ? root.player.trackTitle : ""
          textFormat: Text.PlainText
          color: Color.popupText
          font.family: Style.fontFamily
          font.pixelSize: Style.fontSize + 2
          font.bold: true
          wrapMode: Text.Wrap
          maximumLineCount: 2
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
      height: 44
      visible: !!root.player

      Row {
        anchors.centerIn: parent
        spacing: 18

        // Shuffle and repeat only where the player offers them -- a browser tab does
        // not -- lit when on.
        TransportButton {
          visible: !!root.player && root.player.shuffleSupported
          glyph: "\u{f049d}"
          lit: !!root.player && root.player.shuffle
          active: !!root.player && root.player.canControl
          onTriggered: root.player.shuffle = !root.player.shuffle
        }

        TransportButton {
          glyph: ""
          active: !!root.player && root.player.canGoPrevious
          onTriggered: root.player.previous()
        }

        TransportButton {
          glyph: (root.player && root.player.isPlaying) ? "" : ""
          size: Style.iconSize + 10
          active: !!root.player && root.player.canTogglePlaying
          onTriggered: root.player.togglePlaying()
        }

        TransportButton {
          glyph: ""
          active: !!root.player && root.player.canGoNext
          onTriggered: root.player.next()
        }

        // Off, then the playlist, then the one track: the order players cycle in.
        TransportButton {
          visible: !!root.player && root.player.loopSupported
          glyph: root.player && root.player.loopState === MprisLoopState.Track ? "\u{f0458}" : "\u{f0456}"
          lit: !!root.player && root.player.loopState !== MprisLoopState.None
          active: !!root.player && root.player.canControl
          onTriggered: {
            var state = root.player.loopState;
            root.player.loopState = state === MprisLoopState.None ? MprisLoopState.Playlist : (state === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None);
          }
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

    // Where it comes out: the default output, which is where a player sends its sound
    // unless told otherwise. A click hands over to the sound panel, which can change it.
    PanelRow {
      visible: !!root.player && !!Pipewire.defaultAudioSink
      icon: "\u{f057e}"
      label: Pipewire.defaultAudioSink ? (Pipewire.defaultAudioSink.description || Pipewire.defaultAudioSink.name) : ""
      sublabel: "playing through  ·  click to change"
      onClicked: Quickshell.execDetached(["desktop-shell", "shell", "togglePanel", "audio"])
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
    property bool lit: false
    property int size: Style.iconSize + 2

    signal triggered

    implicitWidth: label.implicitWidth + 16
    implicitHeight: Math.max(26, button.size + 8)

    Text {
      id: label

      anchors.centerIn: parent
      text: button.glyph
      color: button.lit || (mouse.containsMouse && button.active) ? Color.popupAccent : Color.popupText
      opacity: button.active ? 1.0 : 0.35
      font.family: Style.fontFamily
      font.pixelSize: button.size
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
