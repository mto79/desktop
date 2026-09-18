import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Ui

// Microphone panel: the input in use, whether anything is listening to it, how loud you
// are, and the other inputs.
//
// Laid out like the battery panel, and the counterpart of the sound panel -- the two
// icons used to share one. The status line names every app recording from a microphone,
// because that is the question a microphone icon should answer first. The live level is
// the one before a call: speak, and see whether it moves.
Popup {
  id: root

  readonly property string panelId: "microphone"

  readonly property PwNode source: Pipewire.defaultAudioSource

  readonly property int volume: source && source.audio ? Math.round(source.audio.volume * 100) : 0
  readonly property bool muted: source && source.audio ? source.audio.muted : false

  // Debounced snapshot, for the reason the sound panel gives.
  property var sources: []
  property var recorders: []

  readonly property var liveNodes: Pipewire.nodes ? Pipewire.nodes.values : []

  function rebuild() {
    var ins = [];
    var listening = [];
    for (var i = 0; i < liveNodes.length; i++) {
      var n = liveNodes[i];
      if (!n)
        continue;
      var p = n.properties || {};
      if (n.isStream && p["media.class"] === "Stream/Input/Audio") {
        // This panel's own level meter is a capture stream too, and the sound panel's
        // listens to a sink's monitor; neither is someone listening to you.
        if (/quickshell/i.test(p["application.name"] || "") || /quickshell/i.test(p["node.name"] || ""))
          continue;
        listening.push(n);
      } else if (!n.isStream && !n.isSink && n.audio) {
        // A sink's monitor is a source too, but not a microphone.
        if (/\.monitor$/.test(n.name || ""))
          continue;
        ins.push(n);
      }
    }
    sources = ins;
    recorders = listening;
  }

  function label(node) {
    if (!node)
      return "";
    return node.description || node.nickname || node.name || "Unknown";
  }

  function appName(node) {
    var p = node && node.properties ? node.properties : {};
    return p["application.name"] || p["application.process.binary"] || node.name || "Unknown";
  }

  readonly property var recorderNames: {
    var names = [];
    for (var i = 0; i < recorders.length; i++) {
      var name = appName(recorders[i]);
      if (names.indexOf(name) === -1)
        names.push(name);
    }
    return names;
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

  PwObjectTracker {
    objects: root.sources.concat(root.recorders)
  }

  // Only while open. Muted, the source still carries sound -- mute is applied after it --
  // so the meter keeps moving; the colour says it is going nowhere.
  PwNodePeakMonitor {
    id: peak

    node: root.source
    enabled: root.visible && !!root.source
  }

  contentWidth: Style.popupWidth
  contentHeight: column.implicitHeight + Style.popupPadding * 2

  Column {
    id: column

    width: parent.width
    spacing: 2

    // --- The input, big ---------------------------------------------------------------
    PanelHero {
      icon: root.muted ? "\u{f036d}" : "\u{f036c}"
      iconColor: root.muted ? Color.popupUrgent : (root.recorders.length > 0 ? Color.popupAccent : Color.popupText)
      title: root.source ? root.label(root.source) : "No microphone"
      status: {
        if (!root.source)
          return "";
        if (root.muted)
          return root.recorders.length > 0 ? "MUTED  ·  " + root.recorderNames.join(", ") + " GETS SILENCE" : "MUTED";
        if (root.recorders.length === 0)
          return "NOT IN USE";
        return ("listening  ·  " + root.recorderNames.join(", "));
      }
      statusColor: root.muted ? Color.popupUrgent : (root.recorders.length > 0 ? Color.popupAccent : Color.popupMuted)
      value: root.source ? root.volume + "%" : "—"
      valueColor: root.muted ? Color.popupMuted : Color.popupText
      struck: root.muted
      iconClickable: true
      // The icon is the mute button, as it is on the bar.
      onIconClicked: if (root.source && root.source.audio)
        root.source.audio.muted = !root.source.audio.muted
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
        enabled: !!root.source
        value: root.source && root.source.audio ? root.source.audio.volume : 0
        fillColor: root.muted ? Color.popupMuted : Color.popupAccent
        onMoved: v => {
          if (root.source && root.source.audio)
            root.source.audio.volume = v;
        }
      }
    }

    PanelLevel {
      caption: "you"
      level: peak.peak
      fillColor: root.muted ? Color.popupMuted : Color.popupAccent
    }

    // --- Who is listening -------------------------------------------------------------
    PanelSection {
      title: "Listening"
      value: root.recorders.length > 0 ? root.recorders.length + (root.recorders.length === 1 ? " stream" : " streams") : ""
      rule: true
      visible: root.recorders.length > 0
    }

    Repeater {
      model: root.recorders

      delegate: PanelRow {
        required property var modelData

        icon: "\u{f036c}"
        label: root.appName(modelData)
        sublabel: {
          var p = modelData && modelData.properties ? modelData.properties : {};
          return p["media.name"] || p["node.name"] || "";
        }
        active: !root.muted
        enabled: false
      }
    }

    // --- Where it comes from ----------------------------------------------------------
    PanelSection {
      title: "Input"
      value: root.sources.length > 1 ? "click to switch" : ""
      rule: true
    }

    Repeater {
      model: root.sources

      delegate: PanelRow {
        required property var modelData

        icon: root.source && modelData && root.source.id === modelData.id ? "" : " "
        label: root.label(modelData)
        active: root.source && modelData && root.source.id === modelData.id
        onClicked: if (modelData)
          Pipewire.preferredDefaultAudioSource = modelData
      }
    }

    // --- The microphone's other uses on this desk -------------------------------------
    PanelSection {
      title: "Also"
      rule: true
    }

    PanelRow {
      visible: Shortcuts.dictation !== ""
      icon: "\u{f036c}"
      label: "Dictate"
      sublabel: "Hold " + Shortcuts.dictation.replace(", hold", "") + " and speak, or click to start"
      onClicked: {
        root.close();
        Quickshell.execDetached(["voxtype", "record", "toggle"]);
      }
    }

    PanelRow {
      icon: ""
      label: "Open wiremix"
      sublabel: "Every stream, device and port"
      onClicked: {
        root.close();
        Quickshell.execDetached({
          command: ["desktop-launch-audio"],
          workingDirectory: Quickshell.env("HOME")
        });
      }
    }
  }
}
