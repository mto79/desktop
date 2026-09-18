import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Ui

// Meeting capture panel: what will be recorded before you start, how long it has been
// going once you have, and the transcripts it left behind.
//
// Laid out like the battery panel: the clock big while capturing. The part worth having
// before a call is the check desktop-meeting-capture otherwise only makes when it starts:
// both sides are recorded -- your microphone as one channel, the speakers' monitor as the
// other -- so a muted microphone means a transcript without you in it, and music left
// playing is transcribed into the middle of the meeting. Both are shown here, in red,
// before the button is pressed rather than as a notification after.
Popup {
  id: root

  readonly property string panelId: "capture"

  property bool active: false
  property bool transcribing: false
  property int polledElapsed: 0
  property real polledAt: 0
  property int elapsed: 0

  property var captures: []

  readonly property PwNode source: Pipewire.defaultAudioSource
  readonly property PwNode sink: Pipewire.defaultAudioSink
  readonly property bool micMuted: source && source.audio ? source.audio.muted : false

  // Everything else playing to the speakers, which the monitor side records too.
  property var others: []

  readonly property var liveNodes: Pipewire.nodes ? Pipewire.nodes.values : []
  readonly property var streamNodes: liveNodes.filter(function (n) {
    return n && n.isStream;
  })

  PwObjectTracker {
    objects: root.streamNodes.concat(root.source ? [root.source] : [], root.sink ? [root.sink] : [])
  }

  function rebuild() {
    var names = [];
    for (var i = 0; i < streamNodes.length; i++) {
      var p = streamNodes[i].properties || {};
      if (p["media.class"] !== "Stream/Output/Audio")
        continue;
      var name = p["application.name"] || p["application.process.binary"] || "";
      if (name !== "" && names.indexOf(name) === -1)
        names.push(name);
    }
    others = names;
  }

  function clock(seconds) {
    var hours = Math.floor(seconds / 3600);
    var minutes = Math.floor((seconds % 3600) / 60);
    var rest = seconds % 60;
    var mm = (hours > 0 && minutes < 10 ? "0" : "") + minutes;
    return (hours > 0 ? hours + ":" : "") + mm + ":" + (rest < 10 ? "0" : "") + rest;
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

  Process {
    id: statusProbe

    command: ["desktop-status-meeting-capture"]

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var data = JSON.parse(text);
          var wasBusy = root.active || root.transcribing;
          root.active = !!data.active;
          root.transcribing = !!data.transcribing;
          root.polledElapsed = data.elapsed || 0;
          root.polledAt = Date.now();
          root.elapsed = root.polledElapsed;
          // A transcript just landed: the list has something new.
          if (wasBusy && !root.active && !root.transcribing && !listProbe.running)
            listProbe.running = true;
        } catch (e) {}
      }
    }
  }

  Process {
    id: listProbe

    command: ["desktop-captures", "meetings"]

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          root.captures = JSON.parse(text);
        } catch (e) {}
      }
    }
  }

  Timer {
    interval: 2000
    repeat: true
    running: root.visible
    triggeredOnStart: true
    onTriggered: {
      if (!statusProbe.running)
        statusProbe.running = true;
      root.rebuild();
    }
  }

  Timer {
    interval: 1000
    repeat: true
    running: root.visible && root.active
    onTriggered: root.elapsed = root.polledElapsed + Math.floor((Date.now() - root.polledAt) / 1000)
  }

  onVisibleChanged: if (visible && !listProbe.running)
    listProbe.running = true

  contentWidth: Style.popupWidth
  contentHeight: column.implicitHeight + Style.popupPadding * 2

  Column {
    id: column

    width: parent.width
    spacing: 2

    PanelHero {
      icon: "\u{f02ce}"
      iconColor: root.active ? Color.popupUrgent : (root.transcribing ? Color.popupAccent : Color.popupText)
      title: "Meeting capture"
      spinning: root.transcribing
      status: {
        if (root.active)
          return "recording both sides";
        if (root.transcribing)
          return "transcribing, on this machine";
        var key = Shortcuts.forExec("desktop-meeting-capture toggle");
        return "ready" + (key !== "" ? "  ·  " + key : "");
      }
      statusColor: root.active ? Color.popupUrgent : (root.transcribing ? Color.popupAccent : Color.popupMuted)
      value: root.active ? root.clock(root.elapsed) : (root.transcribing ? "…" : String(root.captures.length))
      valueColor: root.active ? Color.popupUrgent : Color.popupMuted
    }

    // --- What will be recorded ----------------------------------------------------------
    PanelSection {
      title: root.active ? "Recording" : "Will record"
      rule: true
    }

    PanelRow {
      icon: root.micMuted ? "\u{f036d}" : "\u{f036c}"
      label: "You  ·  " + (root.source ? (root.source.description || root.source.name) : "no microphone")
      sublabel: root.micMuted ? "Muted: the transcript will have only the other side" : "Your microphone, as its own channel"
      active: root.micMuted
      accentColor: Color.popupUrgent
      // One click to fix the thing it warns about.
      onClicked: if (root.micMuted && root.source && root.source.audio)
        root.source.audio.muted = false
    }

    PanelRow {
      icon: "\u{f057e}"
      label: "Them  ·  " + (root.sink ? (root.sink.description || root.sink.name) : "no output")
      sublabel: root.others.length > 0 ? "Also playing, and recorded with them: " + root.others.join(", ") : "Whatever the call plays through the speakers"
      active: root.others.length > 0
      accentColor: Color.popupUrgent
    }

    PanelRow {
      icon: root.active ? "\u{f04db}" : "\u{f044a}"
      label: root.active ? "Stop and transcribe" : (root.transcribing ? "Transcribing..." : "Start capturing")
      sublabel: root.active ? "The transcript lands beside the recording" : "Stays on this machine; nobody else in the call is told"
      active: root.active
      enabled: !root.transcribing
      onClicked: {
        root.close();
        root.launch(["desktop-meeting-capture", "toggle"]);
      }
    }

    // --- What it left behind ------------------------------------------------------------
    PanelSection {
      title: "Recent"
      value: root.captures.length > 0 ? "click to read  ·  right-click to listen" : ""
      rule: true
    }

    Repeater {
      model: root.captures.slice(0, 4)

      delegate: PanelRow {
        required property var modelData

        icon: modelData.transcript ? "\u{f0219}" : "\u{f0386}"
        label: modelData.preview !== "" ? modelData.preview : modelData.name + "  ·  " + root.when(modelData.at)
        sublabel: {
          var parts = [];
          if (modelData.preview !== "")
            parts.push(modelData.name + "  " + root.when(modelData.at));
          parts.push(root.clock(modelData.seconds));
          parts.push(modelData.transcript ? modelData.words + " words" : "no transcript");
          return parts.join("  ·  ");
        }
        onClicked: {
          root.close();
          root.launch(modelData.transcript ? ["desktop-launch-editor", modelData.transcript] : ["xdg-open", modelData.path]);
        }
        onRightClicked: {
          root.close();
          root.launch(["xdg-open", modelData.path]);
        }
      }
    }

    PanelRow {
      visible: root.captures.length === 0
      icon: "\u{f0386}"
      label: "No captures yet"
      sublabel: "Recordings and transcripts go to Videos/Meetings"
      enabled: false
    }

    PanelRow {
      icon: "\u{f0770}"
      label: "Open Meetings"
      sublabel: "Every recording and transcript"
      onClicked: {
        root.close();
        root.launch(["desktop-launch-files", Quickshell.env("HOME") + "/Videos/Meetings"]);
      }
    }
  }
}
