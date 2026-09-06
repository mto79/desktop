import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Ui

// The volume/brightness overlay, replacing the notify-send calls the media keys used
// to fire at mako.
//
// Volume needs no trigger from the keybindings: it watches PipeWire, so the overlay
// appears whether the change came from a media key, the audio panel, a scroll on the
// bar widget, or another application entirely. Brightness has no such bus -- sysfs does
// not reliably报 inotify -- so the keybinding says so over IPC and this reads the value
// back from brightnessctl, the same tool that set it.
Item {
  id: root

  // The `osd` subtree of shell.json.
  property var config: ({})

  readonly property string position: (config && config.position) ? config.position : "bottom"
  readonly property int margin: (config && config.margin) ? config.margin : 80
  readonly property int timeout: (config && config.timeout) ? config.timeout : 1500

  property string icon: ""
  property string label: ""
  property real value: 0
  property bool active: false

  readonly property PwNode sink: Pipewire.defaultAudioSink
  readonly property PwNode source: Pipewire.defaultAudioSource

  // Without this the nodes' volume properties stay unbound and always read zero.
  PwObjectTracker {
    objects: [root.sink, root.source].filter(function (node) {
      return node !== null;
    })
  }

  // PipeWire settles during startup, and every one of those first values arrives as a
  // change. Nobody wants an OSD for logging in.
  property bool ready: false

  Timer {
    interval: 2000
    running: true
    onTriggered: root.ready = true
  }

  Timer {
    id: hideTimer

    interval: root.timeout
    onTriggered: root.active = false
  }

  function present(icon, value, label) {
    root.icon = icon;
    root.value = value;
    root.label = label;
    root.active = true;
    hideTimer.restart();
  }

  // The same speaker ramp the audio widget uses, written as escapes: a literal glyph
  // does not survive every way this file gets edited.
  readonly property var volumeIcons: ["\uf026", "\uf027", "\uf027", "\uf028"]

  function showVolume() {
    if (!ready || !sink || !sink.audio)
      return;
    var percent = Math.round(sink.audio.volume * 100);
    var icon = "\u{f075f}";
    if (!sink.audio.muted)
      icon = volumeIcons[Math.min(3, Math.max(0, Math.floor(percent / 34)))];
    present(icon, sink.audio.muted ? 0 : sink.audio.volume, sink.audio.muted ? "muted" : percent + "%");
  }

  function showMic() {
    if (!ready || !source || !source.audio)
      return;
    var percent = Math.round(source.audio.volume * 100);
    present(source.audio.muted ? "\u{f036d}" : "\uf130", source.audio.muted ? 0 : source.audio.volume, source.audio.muted ? "muted" : percent + "%");
  }

  // Watched as bound values rather than through Connections on the node's own signals:
  // a property binding cannot be wrong about what the notify signal is called, and this
  // is the part that has to fire for the overlay to exist at all.
  readonly property real sinkVolume: (sink && sink.audio) ? sink.audio.volume : 0
  readonly property bool sinkMuted: (sink && sink.audio) ? sink.audio.muted : false
  readonly property bool sourceMuted: (source && source.audio) ? source.audio.muted : false

  onSinkVolumeChanged: showVolume()
  onSinkMutedChanged: showVolume()
  onSourceMutedChanged: showMic()

  // brightnessctl -m prints `name,class,current,percent,max`, and reading it back is
  // what keeps the overlay honest about the device the key actually changed.
  Process {
    id: brightnessProbe

    command: ["brightnessctl", "-m"]

    stdout: StdioCollector {
      onStreamFinished: {
        var fields = text.trim().split("\n")[0].split(",");
        if (fields.length < 5)
          return;
        var current = parseInt(fields[2], 10) || 0;
        var max = parseInt(fields[4], 10) || 1;
        var fraction = Math.max(0, Math.min(1, current / max));
        root.present(fraction > 0.5 ? "\u{f00de}" : "\u{f00db}", fraction, Math.round(fraction * 100) + "%");
      }
    }
  }

  // Called from shell.qml's IPC handler.
  function show(kind) {
    if (kind === "volume") {
      ready = true;
      showVolume();
      return true;
    }
    if (kind === "mic") {
      ready = true;
      showMic();
      return true;
    }
    if (kind === "brightness") {
      if (!brightnessProbe.running)
        brightnessProbe.running = true;
      return true;
    }
    return false;
  }

  // One overlay per screen: which monitor the user is looking at is not something this
  // needs to guess, and a duplicate on the other head is cheap.
  Variants {
    model: Quickshell.screens

    delegate: Component {
      ScreenSurface {
        required property var modelData

        screen: modelData
        visible: root.active
        position: root.position
        margin: root.margin

        Rectangle {
          width: 260
          height: 52
          radius: Style.radius
          color: Color.popupBackground
          border.width: 1
          border.color: Color.popupBorder

          Text {
            id: glyph

            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            width: 22
            text: root.icon
            color: Color.popupText
            font.family: Style.fontFamily
            font.pixelSize: Style.iconSize + 3
            horizontalAlignment: Text.AlignHCenter
          }

          Text {
            id: reading

            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            color: Color.popupMuted
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSize
          }

          Rectangle {
            id: track

            anchors.left: glyph.right
            anchors.leftMargin: 12
            anchors.right: reading.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            height: 5
            radius: height / 2
            color: Color.popupBorder

            Rectangle {
              width: Math.round(parent.width * Math.max(0, Math.min(1, root.value)))
              height: parent.height
              radius: parent.radius
              color: Color.popupAccent

              Behavior on width {
                NumberAnimation {
                  duration: 90
                }
              }
            }
          }
        }
      }
    }
  }
}
