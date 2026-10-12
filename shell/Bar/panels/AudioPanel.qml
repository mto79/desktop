import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Ui

// Sound panel: the output in use, how loud, what is playing on it, and the other outputs.
//
// Laid out like the battery panel: the device and its volume big at the top, then a live
// level -- whether sound is actually leaving, which a volume of 40% does not say -- then
// each app playing, with its own volume. The microphone has its own panel now; the two
// used to share this one, and the microphone icon opened a panel that was mostly about
// speakers.
//
// A Sony headset gets a section of its own -- battery, and noise cancelling as three
// buttons -- because that is where you look when the room is too loud, not under
// Bluetooth. PipeWire knows none of it; desktop-headset asks the headset.
//
// Everything else here reads and writes Quickshell's PipeWire binding directly. There is no
// `wpctl set-default` call: `preferredDefaultAudioSink` writes the same
// `default.configured.audio.sink` metadata key that wpctl does and that WirePlumber
// persists, so doing both would mean two writers racing over one key.
Popup {
  id: root

  readonly property string panelId: "audio"

  readonly property PwNode sink: Pipewire.defaultAudioSink

  readonly property int volume: sink && sink.audio ? Math.round(sink.audio.volume * 100) : 0
  readonly property bool muted: sink && sink.audio ? sink.audio.muted : false

  // Live PipeWire model -> debounced snapshot. PipeWire can remove a node while
  // Quickshell is still dispatching the removal signal; rebuilding a Repeater from
  // inside that dispatch is what crashes the service. A timer moves the rebuild to the
  // next event-loop turn. The delegates still hold live PwNode objects, which is both
  // fine and necessary -- the slider needs node.audio -- so every access null-guards.
  property var sinks: []
  property var streams: []

  readonly property var liveNodes: Pipewire.nodes ? Pipewire.nodes.values : []

  function rebuild() {
    var outs = [];
    var playing = [];
    for (var i = 0; i < liveNodes.length; i++) {
      var n = liveNodes[i];
      if (!n)
        continue;
      var mediaClass = n.properties ? n.properties["media.class"] : "";
      if (n.isStream && mediaClass === "Stream/Output/Audio")
        playing.push(n);
      else if (!n.isStream && n.isSink && n.audio)
        outs.push(n);
    }
    sinks = outs;
    streams = playing;
  }

  function label(node) {
    if (!node)
      return "";
    return node.description || node.nickname || node.name || "Unknown";
  }

  // An app names itself in application.name; what it is playing, when it says, is
  // media.name -- a track title for Spotify, a page title for a browser tab.
  function appName(node) {
    var p = node && node.properties ? node.properties : {};
    return p["application.name"] || p["application.process.binary"] || node.name || "Unknown";
  }

  function mediaName(node) {
    var p = node && node.properties ? node.properties : {};
    var title = p["media.title"] || p["media.name"] || "";
    // Browsers and SDL fill media.name with a generic "Playback" or "audio stream".
    return /^(playback|audio stream|output|simple dmix)$/i.test(title) ? "" : title;
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

  // A node's properties and volume only arrive once it is tracked, and which nodes are
  // streams is known before either -- so every stream is tracked, and the snapshot is
  // taken again while the panel is open, to pick up what arrived since. Filtering on
  // properties first and tracking what passed would never track a stream at all.
  readonly property var streamNodes: liveNodes.filter(function (n) {
    return n && n.isStream;
  })

  PwObjectTracker {
    objects: root.streamNodes
  }

  Timer {
    interval: 1000
    repeat: true
    running: root.visible
    onTriggered: root.rebuild()
  }

  // Binding the tracker to the snapshot rather than the live model keeps it in step
  // with what the delegates actually reference -- and a stream's properties and volume
  // are only populated for a tracked node.
  PwObjectTracker {
    objects: root.sinks.concat(root.streams)
  }

  // Only while open: the monitor is a capture stream on the sink's monitor port.
  PwNodePeakMonitor {
    id: peak

    node: root.sink
    enabled: root.visible && !!root.sink
  }

  // What desktop-headset last said. `present` is a connected headset that speaks Sony's
  // protocol; `reachable` is whether it answered -- it does not while the phone app
  // holds the channel, and then there is a battery from bluez and nothing to switch.
  property var headset: ({
      present: false
    })
  readonly property bool hasHeadset: headset.present === true
  readonly property bool headsetAnswers: hasHeadset && headset.reachable === true

  readonly property int headsetBattery: {
    if (headsetAnswers && headset.battery !== undefined)
      return headset.battery;
    var readings = BluetoothBattery.readings;
    for (var i = 0; i < readings.length; i++)
      if (readings[i].address === headset.address)
        return readings[i].level;
    return -1;
  }

  // The wind-noise variant is noise cancelling to anyone choosing between three buttons.
  readonly property var headsetModes: [
    {
      id: "nc",
      icon: "\u{f0a45}",
      label: "Cancelling"
    },
    {
      id: "ambient",
      icon: "\u{f07c5}",
      label: "Ambient"
    },
    {
      id: "off",
      icon: "\u{f02cb}",
      label: "Off"
    }
  ]

  function readHeadset(text) {
    try {
      root.headset = JSON.parse(text);
    } catch (e) {}
  }

  Process {
    id: headsetProbe

    command: ["desktop-headset", "status"]

    stdout: StdioCollector {
      onStreamFinished: root.readHeadset(text)
    }
  }

  // Prints the status after switching, so the buttons settle on what the headset did
  // rather than on what was asked of it.
  Process {
    id: headsetSet

    stdout: StdioCollector {
      onStreamFinished: root.readHeadset(text)
    }
  }

  function setHeadsetMode(mode) {
    if (!headsetAnswers || headsetSet.running || headset.mode === mode)
      return;
    // One conversation at a time: the headset has a single channel for this.
    headsetProbe.running = false;
    headset = Object.assign({}, headset, {
      mode: mode
    });
    headsetSet.command = ["desktop-headset", "mode", mode, headset.address];
    headsetSet.running = true;
  }

  // Only while open, and at once on opening. The button on the headset changes the
  // mode too, and nothing tells the panel when it does.
  Timer {
    interval: 10000
    repeat: true
    running: root.visible
    triggeredOnStart: true
    onTriggered: if (!headsetProbe.running && !headsetSet.running)
      headsetProbe.running = true
  }

  contentWidth: Style.popupWidth
  contentHeight: column.implicitHeight + Style.popupPadding * 2

  Column {
    id: column

    width: parent.width
    spacing: 2

    // --- The output, big ----------------------------------------------------------------
    PanelHero {
      icon: root.muted ? "\u{f075f}" : "\u{f057e}"
      iconColor: root.muted ? Color.popupMuted : Color.popupText
      title: root.sink ? root.label(root.sink) : "No output"
      status: {
        if (!root.sink)
          return "";
        if (root.muted)
          return "MUTED  ·  CLICK THE SPEAKER";
        if (root.streams.length === 0)
          return "NOTHING PLAYING";
        var names = [];
        for (var i = 0; i < root.streams.length; i++) {
          var name = root.appName(root.streams[i]);
          if (names.indexOf(name) === -1)
            names.push(name);
        }
        return ("playing  ·  " + names.join(", "));
      }
      statusColor: root.muted ? Color.popupUrgent : Color.popupMuted
      value: root.sink ? root.volume + "%" : "—"
      valueColor: root.muted ? Color.popupMuted : Color.popupText
      struck: root.muted
      iconClickable: true
      // The icon is the mute button, as it is on the bar.
      onIconClicked: if (root.sink && root.sink.audio)
        root.sink.audio.muted = !root.sink.audio.muted
    }

    Item {
      width: parent.width
      height: 26

      PanelSlider {
        anchors.left: parent.left
        anchors.leftMargin: 6
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        enabled: !!root.sink
        value: root.sink && root.sink.audio ? root.sink.audio.volume : 0
        fillColor: root.muted ? Color.popupMuted : Color.popupAccent
        onMoved: v => {
          if (root.sink && root.sink.audio)
            root.sink.audio.volume = v;
        }
      }
    }

    // What is leaving the speakers right now. A volume says how loud it would be; this
    // says whether anything is coming out at all -- the answer to "why can't I hear it".
    PanelLevel {
      level: root.muted ? 0 : peak.peak
    }

    // --- The headset: its battery, and what it does about the room -------------------
    PanelSection {
      title: "Headset"
      value: root.headsetAnswers ? "" : "not answering"
      rule: true
      visible: root.hasHeadset
    }

    Item {
      width: parent.width
      height: 34
      visible: root.hasHeadset

      Text {
        id: headsetName

        anchors.left: parent.left
        anchors.leftMargin: 6
        anchors.right: headsetLevel.left
        anchors.rightMargin: 8
        anchors.top: parent.top
        anchors.topMargin: 4
        text: root.headset.name || ""
        color: Color.popupText
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSize - 1
        elide: Text.ElideRight
      }

      Text {
        id: headsetLevel

        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.baseline: headsetName.baseline
        text: root.headsetBattery < 0 ? "" : root.headsetBattery + "%" + (root.headset.charging === true ? "  ·  charging" : "")
        color: root.headsetBattery >= 0 && root.headsetBattery <= BluetoothBattery.threshold ? Color.popupUrgent : Color.popupMuted
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSize - 2
      }

      PanelMeter {
        anchors.left: parent.left
        anchors.leftMargin: 6
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4
        visible: root.headsetBattery >= 0
        value: root.headsetBattery / 100
        fillColor: root.headsetBattery <= BluetoothBattery.threshold ? Color.popupUrgent : Color.popupAccent
      }
    }

    Row {
      id: modeRow

      width: parent.width
      spacing: 6
      leftPadding: 6
      rightPadding: 6
      topPadding: 2
      visible: root.headsetAnswers

      readonly property real cellWidth: (width - leftPadding - rightPadding - spacing * (root.headsetModes.length - 1)) / root.headsetModes.length

      Repeater {
        model: root.headsetModes

        delegate: Rectangle {
          id: cell

          required property var modelData

          readonly property bool active: root.headset.mode === modelData.id || (modelData.id === "nc" && root.headset.mode === "wind")

          width: modeRow.cellWidth
          height: 54
          radius: Style.radius
          color: active ? Color.popupSelected : (area.containsMouse ? Color.popupHover : "transparent")
          border.width: 1
          border.color: active ? Color.popupAccent : Color.popupBorder

          Column {
            anchors.centerIn: parent
            spacing: 3

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: cell.modelData.icon
              color: cell.active ? Color.popupAccent : Color.popupText
              font.family: Style.fontFamily
              font.pixelSize: Style.iconSize + 3
            }

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: cell.modelData.label
              color: cell.active ? Color.popupAccent : Color.popupMuted
              font.family: Style.fontFamily
              font.pixelSize: Style.fontSize - 2
            }
          }

          MouseArea {
            id: area

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.setHeadsetMode(cell.modelData.id)
          }
        }
      }
    }

    // --- Each app playing, with its own volume ----------------------------------------
    PanelSection {
      title: "Playing"
      value: "per app"
      rule: true
      visible: root.streams.length > 0
    }

    Repeater {
      model: root.streams

      delegate: Item {
        id: stream

        required property var modelData

        width: column.width
        height: 50

        Text {
          id: streamName

          anchors.left: parent.left
          anchors.leftMargin: 6
          anchors.top: parent.top
          anchors.topMargin: 4
          width: parent.width - 60
          text: root.appName(stream.modelData) + (root.mediaName(stream.modelData) !== "" ? "  ·  " + root.mediaName(stream.modelData) : "")
          color: Color.popupText
          font.family: Style.fontFamily
          font.pixelSize: Style.fontSize - 1
          elide: Text.ElideRight
        }

        Text {
          anchors.right: parent.right
          anchors.rightMargin: 6
          anchors.baseline: streamName.baseline
          text: stream.modelData && stream.modelData.audio ? (stream.modelData.audio.muted ? "muted" : Math.round(stream.modelData.audio.volume * 100) + "%") : ""
          color: Color.popupMuted
          font.family: Style.fontFamily
          font.pixelSize: Style.fontSize - 2
        }

        PanelSlider {
          anchors.left: parent.left
          anchors.leftMargin: 6
          anchors.right: parent.right
          anchors.rightMargin: 6
          anchors.bottom: parent.bottom
          anchors.bottomMargin: 4
          value: stream.modelData && stream.modelData.audio ? stream.modelData.audio.volume : 0
          fillColor: stream.modelData && stream.modelData.audio && stream.modelData.audio.muted ? Color.popupMuted : Color.popupAccent
          onMoved: v => {
            if (stream.modelData && stream.modelData.audio)
              stream.modelData.audio.volume = v;
          }
        }
      }
    }

    // --- Where it goes ----------------------------------------------------------------
    PanelSection {
      title: "Output"
      value: root.sinks.length > 1 ? "click to switch" : ""
      rule: true
    }

    Repeater {
      model: root.sinks

      delegate: PanelRow {
        required property var modelData

        icon: root.sink && modelData && root.sink.id === modelData.id ? "" : " "
        label: root.label(modelData)
        active: root.sink && modelData && root.sink.id === modelData.id
        onClicked: if (modelData)
          Pipewire.preferredDefaultAudioSink = modelData
      }
    }

    PanelSection {
      title: "Advanced"
      rule: true
    }

    PanelRow {
      icon: ""
      label: "Open wiremix"
      sublabel: "Every stream, device and port"
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
