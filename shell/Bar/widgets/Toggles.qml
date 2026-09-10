import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Screen recording and dictation, as buttons rather than as indicators.
//
// Omarchy's bar keeps a cluster of manual-state toggles in its centre: they light up
// when the mode is on and otherwise stay out of the way, revealed by hovering the bar.
// The cluster is worth taking; the hiding is not, with only two of them. A control you
// cannot see is one you have to remember exists, and the whole point of moving these
// out of a keybinding is not having to. So both sit here always, muted until they have
// something to say, and each is the button that starts the thing as well as the light
// that says it is running.
//
// The recording button counts up. That a recording is running matters far less than
// that it has been running for eleven minutes.
BarWidget {
  id: root

  property bool recording: false
  property string recordingTip: ""
  // Elapsed seconds as of the last poll, and when that poll landed. The label ticks
  // from these rather than asking ps every second for a number it can work out itself.
  property int polledElapsed: 0
  property real polledAt: 0
  property int elapsed: 0

  property string voice: "idle"
  property string voiceLabel: ""
  property string voiceTip: ""

  readonly property bool voiceAvailable: voice !== "missing"

  function pad(value) {
    return value < 10 ? "0" + value : String(value);
  }

  function clock(seconds) {
    var minutes = Math.floor(seconds / 60);
    var rest = seconds % 60;
    if (minutes < 60)
      return minutes + ":" + pad(rest);
    return Math.floor(minutes / 60) + ":" + pad(minutes % 60) + ":" + pad(rest);
  }

  function launch(command) {
    Quickshell.execDetached({
      command: command,
      workingDirectory: Quickshell.env("HOME")
    });
  }

  // One button: a glyph that changes colour with its state, an optional label, and a
  // hover highlight that matches every other widget on the bar.
  component Toggle: Item {
    id: toggle

    property string icon: ""
    property string label: ""
    property bool active: false
    property color tone: Color.barUrgent
    property string tip: ""
    // Draws attention while something is genuinely happening, and only then.
    property bool pulsing: false

    signal triggered
    signal alternate

    readonly property bool hovered: area.containsMouse

    implicitWidth: body.implicitWidth + Style.itemPaddingH * 2
    implicitHeight: root.height

    onHoveredChanged: {
      if (!root.tooltips)
        return;
      if (hovered)
        root.tooltips.request(toggle, tip);
      else
        root.tooltips.release(toggle);
    }

    Rectangle {
      anchors.fill: parent
      radius: Style.barRadius
      color: toggle.hovered ? Color.barHover : "transparent"

      Behavior on color {
        ColorAnimation {
          duration: 100
        }
      }
    }

    IconLabel {
      id: body

      anchors.centerIn: parent
      icon: toggle.icon
      text: toggle.label
      // Muted until it has something to report, so a bar at rest stays quiet, and
      // full-strength under the pointer so it reads as a button rather than a label.
      color: toggle.active ? toggle.tone : (toggle.hovered ? Color.barText : Color.barMuted)

      SequentialAnimation on opacity {
        running: toggle.pulsing
        loops: Animation.Infinite
        alwaysRunToEnd: true

        NumberAnimation {
          to: 0.45
          duration: 900
          easing.type: Easing.InOutQuad
        }
        NumberAnimation {
          to: 1.0
          duration: 900
          easing.type: Easing.InOutQuad
        }
      }

      // A stopped animation leaves whatever opacity it stopped at.
      onOpacityChanged: if (!toggle.pulsing && opacity !== 1.0)
        opacity = 1.0
    }

    MouseArea {
      id: area

      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      onClicked: mouse => {
        if (root.tooltips)
          root.tooltips.release(toggle);
        if (mouse.button === Qt.RightButton)
          toggle.alternate();
        else
          toggle.triggered();
      }
    }
  }

  Process {
    id: recordProbe

    command: ["desktop-status-screenrecord"]

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var data = JSON.parse(text);
          root.recording = !!data.active;
          root.recordingTip = data.tooltip || "";
          root.polledElapsed = data.elapsed || 0;
          root.polledAt = Date.now();
          root.elapsed = root.polledElapsed;
        } catch (e) {
          root.recording = false;
        }
      }
    }
  }

  // Five seconds is enough to notice a recording that started or stopped elsewhere --
  // the keybinding, or wf-recorder dying on its own. The label does not wait for it.
  Timer {
    interval: 5000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!recordProbe.running)
      recordProbe.running = true
  }

  Timer {
    interval: 1000
    running: root.recording
    repeat: true
    onTriggered: root.elapsed = root.polledElapsed + Math.floor((Date.now() - root.polledAt) / 1000)
  }

  // voxtype streams its own state, so dictation needs no polling at all.
  Process {
    id: voiceFollower

    command: ["desktop-status-voxtype"]
    running: true

    stdout: SplitParser {
      onRead: line => {
        try {
          var data = JSON.parse(line);
          root.voice = data.class || "idle";
          root.voiceLabel = data.text || "";
          root.voiceTip = data.tooltip || "";
        } catch (e) {}
      }
    }

    // A follower that dies gets restarted, unless it died because voxtype is not
    // installed -- in which case it would die again, once every two seconds, forever.
    onExited: if (root.voice !== "missing")
      voiceRestart.start()
  }

  Timer {
    id: voiceRestart

    interval: 2000
    onTriggered: if (!voiceFollower.running)
      voiceFollower.running = true
  }

  implicitWidth: row.implicitWidth

  Row {
    id: row

    anchors.centerIn: parent
    height: parent.height

    Toggle {
      // A camera to start with, the record dot once it is running: the state is legible
      // before the colour is, which matters on a themed bar where red is not a given.
      icon: root.recording ? "\u{f0ec2}" : "\u{f0567}"
      label: root.recording ? root.clock(root.elapsed) : ""
      active: root.recording
      pulsing: root.recording
      tone: Color.barUrgent
      tip: root.recording ? root.recordingTip : "Record a region  ·  right-click for a whole screen"

      onTriggered: root.launch(["desktop-cmd-screenrecord"])
      onAlternate: root.launch(["desktop-cmd-screenrecord", "output"])
    }

    Toggle {
      visible: root.voiceAvailable
      icon: "\u{f036c}"
      label: root.voiceLabel
      active: root.voice === "recording" || root.voice === "transcribing"
      // Transcribing is work in progress, not a live microphone; it gets the calmer of
      // the two colours so a glance can tell them apart.
      tone: root.voice === "transcribing" ? Color.barAccent : Color.barUrgent
      pulsing: root.voice === "recording"
      tip: root.voiceTip !== "" ? root.voiceTip : "Dictate  ·  click to start talking"

      onTriggered: root.launch(["voxtype", "record", "toggle"])
    }
  }
}
