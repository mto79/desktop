import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Screen recording panel: whether a recording is running and for how long, the three
// ways to start one, and the last few recordings.
//
// Laid out like the battery panel: the clock big while recording. The bar button used to
// start a region recording on click, with a whole screen on right click, and nothing
// else was reachable -- recording with sound needed a terminal. The panel names all
// three, and the recordings already made, which were a trip to the file manager away.
// The right click on the bar button still starts or stops a region at once.
Popup {
  id: root

  readonly property string panelId: "recording"

  property bool active: false
  property string tool: ""
  property int polledElapsed: 0
  property real polledAt: 0
  property int elapsed: 0

  property var recordings: []
  property string copied: ""

  function clock(seconds) {
    var minutes = Math.floor(seconds / 60);
    var rest = seconds % 60;
    return minutes + ":" + (rest < 10 ? "0" : "") + rest;
  }

  function bytes(value) {
    var units = ["B", "KB", "MB", "GB"];
    var unit = 0;
    while (value >= 1000 && unit < units.length - 1) {
      value /= 1000;
      unit++;
    }
    return (unit === 0 || value >= 100 ? Math.round(value) : value.toFixed(1)) + " " + units[unit];
  }

  function when(epoch) {
    return new Date(epoch * 1000).toLocaleString(Qt.locale("en_GB"), "ddd d MMM  HH:mm");
  }

  function launch(command) {
    Quickshell.execDetached({
      command: command,
      workingDirectory: Quickshell.env("HOME")
    });
  }

  // Starting closes the panel first: slurp takes over the screen to pick the region, and
  // an open panel would be in the recording.
  function record(scope, audio) {
    root.close();
    launch(["desktop-cmd-screenrecord", scope].concat(audio ? ["audio"] : []));
  }

  Process {
    id: statusProbe

    command: ["desktop-status-screenrecord"]

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var data = JSON.parse(text);
          root.active = !!data.active;
          root.tool = data.tool || "";
          root.polledElapsed = data.elapsed || 0;
          root.polledAt = Date.now();
          root.elapsed = root.polledElapsed;
        } catch (e) {}
      }
    }
  }

  Process {
    id: listProbe

    command: ["desktop-captures", "screen"]

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          root.recordings = JSON.parse(text);
        } catch (e) {}
      }
    }
  }

  Timer {
    interval: 3000
    repeat: true
    running: root.visible
    triggeredOnStart: true
    onTriggered: {
      if (!statusProbe.running)
        statusProbe.running = true;
      if (!listProbe.running)
        listProbe.running = true;
    }
  }

  // The clock ticks from the last poll rather than asking ps every second.
  Timer {
    interval: 1000
    repeat: true
    running: root.visible && root.active
    onTriggered: root.elapsed = root.polledElapsed + Math.floor((Date.now() - root.polledAt) / 1000)
  }

  Timer {
    id: copiedTimer

    interval: 1400
    onTriggered: root.copied = ""
  }

  contentWidth: Style.popupWidth
  contentHeight: column.implicitHeight + Style.popupPadding * 2

  Column {
    id: column

    width: parent.width
    spacing: 2

    PanelHero {
      icon: root.active ? "\u{f0ec2}" : "\u{f0567}"
      iconColor: root.active ? Color.popupUrgent : Color.popupText
      title: "Screen recording"
      status: root.active ? "recording  ·  " + root.tool : (Shortcuts.forExec("desktop-cmd-screenrecord region") !== "" ? "ready  ·  " + Shortcuts.forExec("desktop-cmd-screenrecord region") + " for a region" : "ready")
      statusColor: root.active ? Color.popupUrgent : Color.popupMuted
      value: root.active ? root.clock(root.elapsed) : String(root.recordings.length)
      valueColor: root.active ? Color.popupUrgent : Color.popupMuted
    }

    PanelRow {
      visible: root.active
      icon: "\u{f04db}"
      label: "Stop recording"
      sublabel: "Saved to Videos when it stops"
      active: true
      onClicked: {
        root.close();
        root.launch(["desktop-cmd-screenrecord"]);
      }
    }

    PanelSection {
      title: "Record"
      rule: true
      visible: !root.active
    }

    PanelRow {
      visible: !root.active
      icon: "\u{f0e51}"
      label: "A region"
      sublabel: "Drag out the part of the screen to record"
      onClicked: root.record("region", false)
    }

    PanelRow {
      visible: !root.active
      icon: "\u{f0379}"
      label: "A whole screen"
      sublabel: "Click the screen to record"
      onClicked: root.record("output", false)
    }

    PanelRow {
      visible: !root.active
      // wf-recorder's --audio with no device records the default source -- the
      // microphone -- which is what a walkthrough wants: your voice over the screen.
      icon: "\u{f036c}"
      label: "A region, with your voice"
      sublabel: "Records the microphone along with the screen"
      onClicked: root.record("region", true)
    }

    PanelSection {
      title: "Recent"
      value: root.recordings.length > 0 ? "click to play  ·  right-click to copy the path" : ""
      rule: true
    }

    Repeater {
      model: root.recordings.slice(0, 5)

      delegate: PanelRow {
        required property var modelData

        icon: "\u{f0381}"
        label: root.when(modelData.at)
        sublabel: root.clock(modelData.seconds) + "  ·  " + root.bytes(modelData.bytes)
        onClicked: {
          root.close();
          root.launch(["xdg-open", modelData.path]);
        }
        onRightClicked: {
          Quickshell.execDetached(["wl-copy", "--", modelData.path]);
          root.copied = modelData.path;
          copiedTimer.restart();
        }

        Text {
          text: root.copied === modelData.path ? "copied" : ""
          color: Color.popupAccent
          font.family: Style.fontFamily
          font.pixelSize: Style.fontSize - 2
        }
      }
    }

    PanelRow {
      visible: root.recordings.length === 0
      icon: "\u{f0381}"
      label: "No recordings yet"
      sublabel: "They are saved to Videos"
      enabled: false
    }

    PanelRow {
      icon: "\u{f0770}"
      label: "Open Videos"
      sublabel: "Every recording, in the file manager"
      onClicked: {
        root.close();
        root.launch(["desktop-launch-files", Quickshell.env("HOME") + "/Videos"]);
      }
    }
  }
}
