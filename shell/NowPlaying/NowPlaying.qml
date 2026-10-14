import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

// A card when a new track starts: the cover, what it is, and the rest of the artist's
// albums with the one it is from lit -- so a song that comes up on shuffle says where it
// sits in a body of work, not only what it is called.
//
// The albums come from bin/desktop-discography, which asks MusicBrainz and keeps the
// answer a month. The card shows at once with what the player knows and the albums fill
// in when they arrive; an artist MusicBrainz does not know gets the card without them.
//
// One instance, at the shell's root: the bar widget exists per monitor, and a card
// raised from there would come up three times.
Item {
  id: root

  // The `nowPlaying` subtree of shell.json.
  property var config: ({})

  readonly property bool wanted: !(config && config.enabled === false)
  readonly property string position: (config && config.position) ? config.position : "top"
  readonly property int margin: (config && config.margin !== undefined) ? config.margin : 10
  readonly property int timeout: (config && config.timeout) ? config.timeout : 8000

  readonly property var player: Media.active
  readonly property bool playing: !!player && player.isPlaying

  // What the card is about, frozen when it opens: the player's metadata changes under it
  // the moment the next track starts, and a card should not rewrite itself while read.
  property string title: ""
  property string artist: ""
  property string album: ""
  property string art: ""
  property var albums: []
  // "albums", or "releases" for an artist whose EPs and singles stand in for them.
  property string kind: "albums"
  property bool looking: false

  property bool shown: false
  property string lastKey: ""

  // MPRIS sends a track change as several property changes -- title, then artist, then
  // art -- so a key read at the first would be half the next track and half the last.
  // Waiting a moment lets it settle.
  readonly property string trackKey: player ? [player.trackArtist, player.trackTitle].join("\u0001") : ""

  onTrackKeyChanged: settle.restart()
  onPlayingChanged: settle.restart()

  Timer {
    id: settle

    interval: 700
    onTriggered: root.consider()
  }

  // The tracks already playing when the shell starts are not new.
  property bool ready: false

  Timer {
    interval: 3000
    running: true
    onTriggered: {
      root.ready = true;
      root.lastKey = root.trackKey;
    }
  }

  function consider() {
    if (!ready || !wanted || !playing || !player.trackTitle || !player.trackArtist)
      return;
    if (trackKey === lastKey)
      return;
    lastKey = trackKey;
    // Silenced means silenced; the track is still in the bar.
    if (Inbox.doNotDisturb)
      return;
    present();
  }

  // Also behind `desktop-shell shell nowPlaying`, for the track already playing.
  function present() {
    if (!player || !player.trackTitle)
      return false;
    title = player.trackTitle;
    artist = player.trackArtist || "";
    album = player.trackAlbum || "";
    art = player.trackArtUrl || "";
    albums = [];
    looking = artist !== "";
    if (looking) {
      lookup.running = false;
      lookup.command = ["desktop-discography", artist, album];
      lookup.running = true;
    }
    shown = true;
    drain.restart();
    return true;
  }

  function dismiss() {
    shown = false;
  }

  Process {
    id: lookup

    stdout: StdioCollector {
      onStreamFinished: {
        root.looking = false;
        try {
          var parsed = JSON.parse(text);
          root.albums = parsed.albums || [];
          root.kind = parsed.kind || "albums";
        } catch (e) {
          root.albums = [];
        }
      }
    }

    onExited: code => {
      if (code !== 0)
        root.looking = false;
    }
  }

  readonly property int cardWidth: 452
  readonly property int coverSize: 92
  readonly property int thumbSize: 58
  readonly property int perRow: 6

  // On the monitor with the focused window rather than every one: a card about the music
  // is one thing to read, and three copies of it are clutter.
  ScreenSurface {
    screen: Quickshell.screens.find(s => s.name === (Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "")) || Quickshell.screens[0]
    surfaceNamespace: "desktop-now-playing"
    visible: root.shown || card.opacity > 0
    position: root.position
    margin: root.margin
    interactive: true

    Rectangle {
      id: card

      width: root.cardWidth
      height: body.implicitHeight + 28
      radius: Style.radius + 4
      color: Color.popupBackground
      border.width: 1
      border.color: Color.popupBorder
      clip: true

      opacity: root.shown ? 1 : 0
      transform: Translate {
        y: root.shown ? 0 : -Style.motionTravel
        Behavior on y {
          NumberAnimation {
            duration: Style.motionEnter
            easing.type: Easing.OutCubic
          }
        }
      }

      Behavior on opacity {
        NumberAnimation {
          duration: Style.motionEnter
          easing.type: Easing.OutCubic
        }
      }

      // The cover again, blown up and faded behind everything: the card takes on the
      // record's colours without a palette having to be worked out from it.
      Image {
        anchors.fill: parent
        source: root.art
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        opacity: status === Image.Ready ? 0.12 : 0
        sourceSize.width: 64
        smooth: true
      }

      HoverHandler {
        id: hover
      }

      // A click opens the media panel, where the transport is; a right click puts it away.
      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
          root.shown = false;
          if (mouse.button === Qt.LeftButton)
            Quickshell.execDetached(["desktop-shell", "shell", "togglePanel", "media"]);
        }
      }

      Column {
        id: body

        x: 14
        y: 14
        width: parent.width - 28
        spacing: 12

        Row {
          width: parent.width
          spacing: 14

          Rectangle {
            id: cover

            width: root.coverSize
            height: root.coverSize
            radius: Style.radius
            color: Color.popupHover
            clip: true

            Image {
              id: coverArt

              anchors.fill: parent
              source: root.art
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
              visible: status === Image.Ready
            }

            Text {
              anchors.centerIn: parent
              visible: !coverArt.visible
              text: "\u{f075a}"
              color: Color.popupMuted
              font.family: Style.fontFamily
              font.pixelSize: 40
            }
          }

          Column {
            width: parent.width - cover.width - parent.spacing
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Row {
              spacing: 8

              Equalizer {
                anchors.verticalCenter: parent.verticalCenter
                levels: Spectrum.levels
                count: 6
                barWidth: 2
                spacing: 2
                height: 11
                peaks: false
                colorLow: Color.popupAccent
                colorHigh: Color.popupUrgent
                visible: Spectrum.live
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "NOW PLAYING"
                color: Color.popupAccent
                font.family: Style.fontFamily
                font.pixelSize: Style.fontSize - 3
                font.bold: true
                font.letterSpacing: 1.5
              }
            }

            Text {
              width: parent.width
              text: root.title
              textFormat: Text.PlainText
              color: Color.popupText
              font.family: Style.fontFamily
              font.pixelSize: Style.fontSize + 4
              font.bold: true
              wrapMode: Text.Wrap
              maximumLineCount: 2
              elide: Text.ElideRight
            }

            Text {
              width: parent.width
              visible: root.artist !== ""
              text: root.artist
              textFormat: Text.PlainText
              color: Color.popupText
              font.family: Style.fontFamily
              font.pixelSize: Style.fontSize
              elide: Text.ElideRight
            }

            Text {
              width: parent.width
              visible: root.album !== ""
              text: {
                var year = "";
                for (var i = 0; i < root.albums.length; i++)
                  if (root.albums[i].current)
                    year = root.albums[i].year;
                return root.album + (year !== "" ? "  ·  " + year : "");
              }
              textFormat: Text.PlainText
              color: Color.popupMuted
              font.family: Style.fontFamily
              font.pixelSize: Style.fontSize - 1
              elide: Text.ElideRight
            }
          }
        }

        // --- Discography ------------------------------------------------------------
        Item {
          width: parent.width
          height: 14
          visible: root.looking || root.albums.length > 0

          Rectangle {
            anchors.left: parent.left
            anchors.right: heading.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            height: 1
            color: Color.popupBorder
          }

          Text {
            id: heading

            anchors.centerIn: parent
            text: root.looking ? "LOOKING UP THE DISCOGRAPHY" : "DISCOGRAPHY  ·  " + root.albums.length + " " + (root.kind === "releases" ? "RELEASE" : "ALBUM") + (root.albums.length === 1 ? "" : "S")
            color: Color.popupMuted
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSize - 4
            font.bold: true
            font.letterSpacing: 1.5
          }

          Rectangle {
            anchors.left: heading.right
            anchors.leftMargin: 8
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 1
            color: Color.popupBorder
          }
        }

        Grid {
          id: shelf

          visible: root.albums.length > 0
          columns: root.perRow
          columnSpacing: Math.floor((parent.width - root.perRow * root.thumbSize) / (root.perRow - 1))
          rowSpacing: 8

          Repeater {
            model: root.albums

            delegate: Column {
              id: record

              required property var modelData
              required property int index

              width: root.thumbSize
              spacing: 3

              // Each one arrives a beat after the last, left to right: the shelf filling
              // in rather than appearing.
              opacity: 0
              Component.onCompleted: appear.start()

              SequentialAnimation {
                id: appear

                PauseAnimation {
                  duration: record.index * 45
                }
                NumberAnimation {
                  target: record
                  property: "opacity"
                  to: 1
                  duration: Style.motionEnter
                }
              }

              Rectangle {
                width: root.thumbSize
                height: root.thumbSize
                radius: 5
                color: Color.popupHover
                border.width: record.modelData.current ? 2 : 0
                border.color: Color.popupAccent
                clip: true

                Image {
                  id: thumb

                  anchors.fill: parent
                  anchors.margins: parent.border.width
                  source: record.modelData.cover ? "file://" + record.modelData.cover : ""
                  fillMode: Image.PreserveAspectCrop
                  asynchronous: true
                  sourceSize.width: root.thumbSize * 2
                  visible: status === Image.Ready
                  // The others step back, so the eye lands on the one playing.
                  opacity: record.modelData.current || !root.albums.some(a => a.current) ? 1 : 0.55
                }

                Text {
                  anchors.centerIn: parent
                  visible: !thumb.visible
                  text: record.modelData.title.charAt(0).toUpperCase()
                  color: Color.popupMuted
                  font.family: Style.fontFamily
                  font.pixelSize: 22
                  font.bold: true
                }
              }

              Text {
                width: parent.width
                text: record.modelData.year || "—"
                horizontalAlignment: Text.AlignHCenter
                color: record.modelData.current ? Color.popupAccent : Color.popupMuted
                font.family: Style.fontFamily
                font.pixelSize: Style.fontSize - 4
                font.bold: record.modelData.current
              }

              Text {
                width: parent.width
                text: record.modelData.title
                textFormat: Text.PlainText
                horizontalAlignment: Text.AlignHCenter
                color: record.modelData.current ? Color.popupText : Color.popupMuted
                font.family: Style.fontFamily
                font.pixelSize: Style.fontSize - 5
                elide: Text.ElideRight
              }
            }
          }
        }
      }

      // How long is left, as a line along the bottom that runs out. Hovering holds it.
      Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.bottomMargin: 1
        anchors.leftMargin: Style.radius
        height: 2
        radius: 1
        color: Color.popupAccent
        opacity: 0.6
        width: (parent.width - Style.radius * 2) * remaining.fraction

        QtObject {
          id: remaining

          property real fraction: 1
        }
      }

      // The card's clock and the line drawing it are the same thing, so they cannot
      // disagree; hovering pauses both.
      NumberAnimation {
        id: drain

        target: remaining
        property: "fraction"
        from: 1
        to: 0
        duration: root.timeout
        paused: running && hover.hovered
        onFinished: root.shown = false
      }
    }
  }
}
