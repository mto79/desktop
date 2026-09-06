import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Ui

// Audio panel: output devices + volume, input devices + volume.
//
// Everything here reads and writes Quickshell's PipeWire binding directly. There is no
// `wpctl set-default` call: `preferredDefaultAudioSink` writes the same
// `default.configured.audio.sink` metadata key that wpctl does and that WirePlumber
// persists, so doing both would mean two writers racing over one key.
Popup {
  id: root

  readonly property string panelId: "audio"

  readonly property PwNode sink: Pipewire.defaultAudioSink
  readonly property PwNode source: Pipewire.defaultAudioSource

  readonly property int outputVolume: sink && sink.audio ? Math.round(sink.audio.volume * 100) : 0
  readonly property bool outputMuted: sink && sink.audio ? sink.audio.muted : false
  readonly property int inputVolume: source && source.audio ? Math.round(source.audio.volume * 100) : 0
  readonly property bool inputMuted: source && source.audio ? source.audio.muted : false

  // Live PipeWire model -> debounced snapshot. PipeWire can remove a node while
  // Quickshell is still dispatching the removal signal; rebuilding a Repeater from
  // inside that dispatch is what crashes the service. A timer moves the rebuild to the
  // next event-loop turn. The delegates still hold live PwNode objects, which is both
  // fine and necessary -- the slider needs node.audio -- so every access null-guards.
  property var sinks: []
  property var sources: []

  readonly property var liveNodes: Pipewire.nodes ? Pipewire.nodes.values : []

  function rebuild() {
    var outs = [];
    var ins = [];
    for (var i = 0; i < liveNodes.length; i++) {
      var n = liveNodes[i];
      if (!n || n.isStream || !n.audio)
        continue;
      if (n.isSink)
        outs.push(n);
      else
        ins.push(n);
    }
    sinks = outs;
    sources = ins;
  }

  function label(node) {
    if (!node)
      return "";
    return node.description || node.nickname || node.name || "Unknown";
  }

  Timer {
    id: rebuildTimer

    interval: 75
    repeat: false
    onTriggered: root.rebuild()
  }

  onLiveNodesChanged: rebuildTimer.restart()
  onVisibleChanged: if (visible)
    root.rebuild()

  // Binding the tracker to the snapshot rather than the live model keeps it in step
  // with what the delegates actually reference.
  PwObjectTracker {
    objects: root.sinks.concat(root.sources)
  }

  contentWidth: Style.popupWidth
  contentHeight: column.implicitHeight + Style.popupPadding * 2

  Column {
    id: column

    width: parent.width
    spacing: 2

    PanelSection {
      title: "Output"
      value: root.sink ? (root.outputMuted ? "muted" : root.outputVolume + "%") : "none"
    }

    Item {
      width: parent.width
      height: 26

      Text {
        id: outIcon

        anchors.left: parent.left
        anchors.leftMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        text: root.outputMuted ? "\u{f075f}" : "\uf028"
        color: root.outputMuted ? Color.popupMuted : Color.popupText
        font.family: Style.fontFamily
        font.pixelSize: Style.iconSize

        MouseArea {
          anchors.fill: parent
          anchors.margins: -6
          cursorShape: Qt.PointingHandCursor
          onClicked: if (root.sink && root.sink.audio)
            root.sink.audio.muted = !root.sink.audio.muted
        }
      }

      PanelSlider {
        anchors.left: outIcon.right
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        enabled: !!root.sink
        value: root.sink && root.sink.audio ? root.sink.audio.volume : 0
        fillColor: root.outputMuted ? Color.popupMuted : Color.popupAccent
        onMoved: v => {
          if (root.sink && root.sink.audio)
            root.sink.audio.volume = v;
        }
      }
    }

    Repeater {
      model: root.sinks

      delegate: PanelRow {
        required property var modelData

        icon: root.sink && modelData && root.sink.id === modelData.id ? "\uf00c" : " "
        label: root.label(modelData)
        active: root.sink && modelData && root.sink.id === modelData.id
        onClicked: if (modelData)
          Pipewire.preferredDefaultAudioSink = modelData
      }
    }

    PanelSection {
      title: "Input"
      value: root.source ? (root.inputMuted ? "muted" : root.inputVolume + "%") : "none"
      rule: true
      visible: !!root.source
    }

    Item {
      width: parent.width
      height: 26
      visible: !!root.source

      Text {
        id: inIcon

        anchors.left: parent.left
        anchors.leftMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        text: root.inputMuted ? "\u{f036d}" : "\uf130"
        color: root.inputMuted ? Color.popupUrgent : Color.popupText
        font.family: Style.fontFamily
        font.pixelSize: Style.iconSize

        MouseArea {
          anchors.fill: parent
          anchors.margins: -6
          cursorShape: Qt.PointingHandCursor
          onClicked: if (root.source && root.source.audio)
            root.source.audio.muted = !root.source.audio.muted
        }
      }

      PanelSlider {
        anchors.left: inIcon.right
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        value: root.source && root.source.audio ? root.source.audio.volume : 0
        fillColor: root.inputMuted ? Color.popupMuted : Color.popupAccent
        onMoved: v => {
          if (root.source && root.source.audio)
            root.source.audio.volume = v;
        }
      }
    }

    Repeater {
      model: root.sources

      delegate: PanelRow {
        required property var modelData

        icon: root.source && modelData && root.source.id === modelData.id ? "\uf00c" : " "
        label: root.label(modelData)
        active: root.source && modelData && root.source.id === modelData.id
        onClicked: if (modelData)
          Pipewire.preferredDefaultAudioSource = modelData
      }
    }

    PanelSection {
      title: "Advanced"
      rule: true
    }

    PanelRow {
      icon: "\uf120"
      label: "Open wiremix"
      sublabel: "Per-app mixer"
      onClicked: {
        root.close();
        // workingDirectory: see the comment in BarItem -- cwd-relative config paths.
        Quickshell.execDetached({
          command: ["desktop-launch-audio"],
          workingDirectory: Quickshell.env("HOME")
        });
      }
    }
  }
}
