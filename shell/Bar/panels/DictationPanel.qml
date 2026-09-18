import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Dictation panel: whether voxtype is ready, how it is set up, and what was dictated.
//
// Laid out like the battery panel: the state big at the top, the setup in a grid, then
// the last few dictations from voxtype's journal. Those are there for two reasons.
// Text typed into the wrong window is otherwise gone, and a click copies it again. And
// the recording limit is easy to hit without noticing: voxtype stops listening at
// max_duration_secs and types what it has, mid-sentence. A dictation that ran to the
// limit is marked, so a cut-off sentence has an explanation.
Popup {
  id: root

  readonly property string panelId: "dictation"

  property var details: null
  property string state: "idle"
  property real startedAt: 0
  property int elapsed: 0
  property string copied: ""

  readonly property bool running: !!(details && details.running)
  readonly property int limit: details && details.maxSeconds ? details.maxSeconds : 0

  function cutOff(entry) {
    return limit > 0 && entry.spoken >= limit - 0.3;
  }

  function when(stamp) {
    var parts = stamp.split(" ");
    var date = parts[0].split("-");
    var day = new Date(Number(date[0]), Number(date[1]) - 1, Number(date[2]));
    var today = new Date();
    today.setHours(0, 0, 0, 0);
    var label = day.getTime() === today.getTime() ? "today" : day.toLocaleDateString(Qt.locale("en_GB"), "ddd d MMM");
    return label + " " + parts[1];
  }

  Process {
    id: detailsProbe

    command: ["desktop-dictation-details"]

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          root.details = JSON.parse(text);
        } catch (e) {}
      }
    }
  }

  // voxtype's own state, followed only while the panel is open.
  Process {
    id: follower

    command: ["desktop-status-voxtype"]
    running: root.visible

    stdout: SplitParser {
      onRead: line => {
        try {
          var next = JSON.parse(line).class || "idle";
          if (next === "recording" && root.state !== "recording")
            root.startedAt = Date.now();
          // A dictation just finished: the journal has a new line for the list.
          if (next === "idle" && root.state === "transcribing")
            refreshAfter.restart();
          root.state = next;
        } catch (e) {}
      }
    }
  }

  Timer {
    id: refreshAfter

    interval: 500
    onTriggered: detailsProbe.running = true
  }

  Timer {
    interval: 250
    repeat: true
    running: root.visible && root.state === "recording"
    onTriggered: root.elapsed = Math.floor((Date.now() - root.startedAt) / 1000)
  }

  Timer {
    id: copiedTimer

    interval: 1400
    onTriggered: root.copied = ""
  }

  onVisibleChanged: if (visible && !detailsProbe.running)
    detailsProbe.running = true

  function launch(command) {
    Quickshell.execDetached({
      command: command,
      workingDirectory: Quickshell.env("HOME")
    });
  }

  contentWidth: Style.popupWidth
  contentHeight: column.implicitHeight + Style.popupPadding * 2

  Column {
    id: column

    width: parent.width
    spacing: 2

    PanelHero {
      icon: "\u{f036c}"
      iconColor: root.state === "recording" ? Color.popupUrgent : (root.state === "transcribing" ? Color.popupAccent : Color.popupText)
      title: "Dictation"
      spinning: root.state === "transcribing"
      status: {
        if (!root.details)
          return "";
        if (!root.details.installed)
          return "voxtype is not installed";
        if (!root.running)
          return "not running";
        if (root.state === "recording")
          return "listening  ·  let go to type it";
        if (root.state === "transcribing")
          return "transcribing";
        return "ready  ·  " + root.details.key;
      }
      statusColor: root.details && root.details.installed && !root.running ? Color.popupUrgent : (root.state === "recording" ? Color.popupUrgent : Color.popupMuted)
      // Listening: seconds against the limit, since the limit is where it cuts off.
      value: root.state === "recording" ? root.elapsed + (root.limit > 0 ? "/" + root.limit : "") + "s" : (root.details && root.details.languages ? root.details.languages.join(" ") : "")
      valueColor: root.state === "recording" && root.limit > 0 && root.elapsed >= root.limit - 3 ? Color.popupUrgent : Color.popupText
    }

    Grid {
      width: parent.width
      columns: 2
      topPadding: 2
      bottomPadding: 4
      visible: !!(root.details && root.details.installed)

      PanelStat {
        label: "Model"
        value: root.details ? root.details.model.replace(/^large-/, "") : "—"
      }
      PanelStat {
        label: "On"
        value: root.details && root.details.backend ? root.details.backend.replace(/^GPU \((.*)\)$/, "GPU $1") : "CPU"
      }
      PanelStat {
        label: "Limit"
        value: root.limit > 0 ? root.limit + " s" : "none"
      }
      PanelStat {
        label: "Into"
        value: root.details ? (root.details.output === "type" ? "the window" : root.details.output) : "—"
      }
    }

    PanelRow {
      visible: !!(root.details && root.details.installed && !root.running)
      icon: "\u{f0450}"
      label: "Start voxtype"
      sublabel: "The daemon is not running, so the key does nothing"
      active: true
      onClicked: root.launch(["systemctl", "--user", "restart", "voxtype"])
    }

    PanelSection {
      title: "Recent"
      value: root.details && root.details.recent && root.details.recent.length > 0 ? "click to copy again" : ""
      rule: true
    }

    Repeater {
      model: root.details && root.details.recent ? root.details.recent : []

      delegate: PanelRow {
        required property var modelData

        icon: root.cutOff(modelData) ? "\u{f0026}" : "\u{f0219}"
        label: modelData.text
        sublabel: {
          var parts = [root.when(modelData.at), modelData.spoken.toFixed(0) + " s spoken"];
          if (root.cutOff(modelData))
            parts.push("cut off at the " + root.limit + " s limit");
          else
            parts.push(modelData.took.toFixed(1) + " s to type");
          return parts.join("  ·  ");
        }
        onClicked: {
          Quickshell.execDetached(["wl-copy", "--", modelData.text]);
          root.copied = modelData.at;
          copiedTimer.restart();
        }

        Text {
          text: root.copied === modelData.at ? "copied" : ""
          color: Color.popupAccent
          font.family: Style.fontFamily
          font.pixelSize: Style.fontSize - 2
        }
      }
    }

    PanelRow {
      visible: !!(root.details && root.details.recent && root.details.recent.length === 0)
      icon: "\u{f0219}"
      label: "Nothing dictated this week"
      sublabel: root.details ? "Hold " + root.details.key.replace(", hold", "") + " and speak" : ""
      enabled: false
    }

    PanelSection {
      title: "Advanced"
      rule: true
    }

    PanelRow {
      icon: "\u{f036c}"
      label: root.state === "recording" ? "Stop and type it" : "Dictate now"
      sublabel: "The same as holding the key, for when a hand is busy"
      enabled: root.running
      onClicked: {
        root.close();
        root.launch(["voxtype", "record", "toggle"]);
      }
    }

    PanelRow {
      icon: ""
      label: "voxtype settings"
      sublabel: "Model, languages, limit, key"
      onClicked: {
        root.close();
        root.launch(["desktop-launch-editor", Quickshell.env("HOME") + "/.config/voxtype/config.toml"]);
      }
    }
  }
}
