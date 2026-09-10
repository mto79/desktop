import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// AI panel: how much of each Claude limit is gone, and what is still running.
//
// The bar can only ever show the fullest limit as one number. The thing a number cannot
// tell you is which limit that is and how long it has left -- a session at 90% with
// twenty minutes to go is a coffee break, the same 90% on the week is a different plan
// for the next three days. Hence a meter per limit, each with its own reset.
//
// The numbers come from desktop-status-claude --report, which is the same call the bar
// module makes and answers from the same cached response: opening this panel costs no
// extra request, and cannot disagree with the bar it hangs from.
Popup {
  id: root

  readonly property string panelId: "ai"

  property string plan: ""
  property var limits: []
  property var spend: null
  property var tokens: null
  property bool available: false

  property var agents: []

  // Two tones, the same two the bar uses: a limit is either worth noticing or it is
  // not. A third colour would be a distinction nobody reads at a glance.
  function tone(severity, percent) {
    return (severity === "critical" || percent >= 90) ? Color.popupUrgent : Color.popupAccent;
  }

  function launch(command) {
    return {
      command: command,
      workingDirectory: Quickshell.env("HOME")
    };
  }

  Process {
    id: report

    command: ["desktop-status-claude", "--report"]

    function reload() {
      if (!running)
        running = true;
    }

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var data = JSON.parse(text);
          root.plan = data.plan || "";
          root.limits = data.limits || [];
          root.spend = data.spend || null;
          root.tokens = data.tokens || null;
          root.available = !!data.available;
        } catch (e) {
          root.available = false;
        }
      }
    }
  }

  // The count on the bar is a number; here it is worth naming which tools they are.
  Process {
    id: agentProbe

    command: ["desktop-status-agents"]

    function reload() {
      if (!running)
        running = true;
    }

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var data = JSON.parse(text);
          root.agents = (data.text === "") ? [] : String(data.tooltip || "").split(", ");
        } catch (e) {
          root.agents = [];
        }
      }
    }
  }

  // Only while open, and slowly: the report is served from a cache that refuses to be
  // refreshed more than once every five and a half minutes anyway.
  Timer {
    interval: 30000
    repeat: true
    running: root.visible
    triggeredOnStart: true
    onTriggered: {
      report.reload();
      agentProbe.reload();
    }
  }

  contentWidth: Style.popupWidth
  contentHeight: column.implicitHeight + Style.popupPadding * 2

  Column {
    id: column

    width: parent.width
    spacing: 2

    PanelSection {
      title: "Claude Code"
      value: root.plan
    }

    Repeater {
      model: root.limits

      delegate: Item {
        required property var modelData

        width: column.width
        height: 42

        Text {
          id: limitName

          anchors.left: parent.left
          anchors.leftMargin: 6
          anchors.top: parent.top
          anchors.topMargin: 4
          text: parent.modelData.name
          color: Color.popupText
          font.family: Style.fontFamily
          font.pixelSize: Style.fontSize
        }

        Text {
          anchors.right: parent.right
          anchors.rightMargin: 6
          anchors.baseline: limitName.baseline
          text: parent.modelData.percent + "%" + (parent.modelData.resets ? "  ·  resets " + parent.modelData.resets : "")
          color: Color.popupMuted
          font.family: Style.fontFamily
          font.pixelSize: Style.fontSize - 2
        }

        PanelMeter {
          anchors.left: parent.left
          anchors.leftMargin: 6
          anchors.right: parent.right
          anchors.rightMargin: 6
          anchors.top: limitName.bottom
          anchors.topMargin: 7
          value: parent.modelData.percent / 100
          fillColor: root.tone(parent.modelData.severity, parent.modelData.percent)
        }
      }
    }

    // Money, not tokens, which is why it sits under its own heading rather than in the
    // list above: the two are easy to read as one thing and are not.
    PanelSection {
      title: "Extra usage"
      value: root.spend ? root.spend.used + " of " + root.spend.limit : ""
      rule: true
      visible: root.spend !== null
    }

    Item {
      width: column.width
      height: 26
      visible: root.spend !== null

      PanelMeter {
        anchors.left: parent.left
        anchors.leftMargin: 6
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        value: root.spend ? root.spend.percent / 100 : 0
        fillColor: root.spend ? root.tone(root.spend.severity, root.spend.percent) : Color.popupAccent
      }
    }

    PanelSection {
      title: "Tokens"
      value: "last 5h, local"
      rule: true
      visible: root.tokens !== null && root.tokens.any
    }

    PanelRow {
      icon: "\u{f012a}"
      label: root.tokens ? root.tokens.in + " in  ·  " + root.tokens.out + " out" : ""
      // Cache reads are kept apart from the total on purpose: they dominate it and are
      // billed and rate-limited at a fraction of fresh input, so folding them in would
      // make the figure look alarming and mean nothing.
      sublabel: root.tokens ? root.tokens.cached + " read from cache  ·  " + root.tokens.sessions + " session(s)" : ""
      enabled: false
      visible: root.tokens !== null && root.tokens.any
    }

    PanelRow {
      icon: "\u{f0026}"
      label: "Usage limits unavailable"
      sublabel: "offline, or the Claude Code login has expired"
      enabled: false
      visible: !root.available
    }

    PanelSection {
      title: "Agents"
      value: root.agents.length > 0 ? "running" : "idle"
      rule: true
    }

    Repeater {
      model: root.agents

      delegate: PanelRow {
        required property var modelData

        icon: "\u{f06a9}"
        label: modelData
        enabled: false
      }
    }

    PanelRow {
      icon: "\u{f06a9}"
      label: "Nothing running"
      enabled: false
      visible: root.agents.length === 0
    }

    PanelSection {
      title: "Advanced"
      rule: true
    }

    PanelRow {
      icon: "\u{f018d}"
      label: "Agent sessions"
      sublabel: "what is waiting, and where"
      onClicked: {
        root.close();
        Quickshell.execDetached(root.launch(["desktop-menu-agents"]));
      }
    }
  }
}
