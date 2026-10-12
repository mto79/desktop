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

  // One entry per Claude Code session that reports its state through the hooks, needing
  // you first. See desktop-agent-sessions.
  property var sessions: []

  // Whether an agent that needs you is said out loud as well as shown, and which voice
  // says it. desktop-say keeps the switch; this is where it is found and flipped.
  property bool speaking: true
  property string voice: ""

  Process {
    id: sayStatus

    command: ["desktop-say", "--status", "--json"]

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var status = JSON.parse(text);
          root.speaking = status.speaking === true;
          root.voice = status.engine || "";
        } catch (error) {
          // Not installed, or not answering: the row below simply stays as it is.
        }
      }
    }
  }

  Process {
    id: sayToggle

    command: ["desktop-say", "--toggle"]
    onExited: sayStatus.running = true
  }

  // The voices there are to choose from, and whether the list is unfolded. Folded by
  // default: a voice is chosen once, and five rows of them every time the panel opens
  // would be five rows between you and the agents.
  property var voices: []
  property bool choosingVoice: false
  // The one being fetched and tried, so its row can say so: a voice is 60 MB the first time.
  property string fetching: ""

  readonly property string voiceLabel: {
    for (var i = 0; i < voices.length; i++)
      if (voices[i].current)
        return voices[i].label;
    return "";
  }

  Process {
    id: voiceList

    command: ["desktop-say", "--voices", "--json"]

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          root.voices = JSON.parse(text).voices || [];
        } catch (error) {
          root.voices = [];
        }
      }
    }
  }

  Process {
    id: voiceChoose

    onExited: {
      root.fetching = "";
      voiceList.running = true;
      sayStatus.running = true;
    }
  }

  function chooseVoice(name) {
    if (voiceChoose.running)
      return;
    root.fetching = name;
    voiceChoose.command = ["desktop-say", "--voice", name];
    voiceChoose.running = true;
  }
  property int waitingCount: 0

  // Claude processes with no state recorded: open, but idle since the hooks were wired --
  // a session picks the hooks up, but only reports on its next event. Named rather than
  // silently left out, or they would look like nothing running.
  readonly property int unreportedClaude: {
    for (var i = 0; i < agents.length; i++) {
      var match = /^(\d+) claude$/.exec(agents[i]);
      if (match)
        return Math.max(0, Number(match[1]) - sessions.length);
    }
    return 0;
  }
  readonly property var otherAgents: agents.filter(function (entry) {
    return !/ claude$/.test(entry);
  })

  function sessionIcon(state) {
    return state === "waiting" ? "\u{f0026}" : state === "done" ? "\u{f012c}" : "\u{f1049}";
  }

  function sessionText(session) {
    var what = {
      "waiting": "waiting for you",
      "working": "working",
      "done": "finished",
      "ready": "open, nothing asked yet"
    }[session.state] || session.state;
    var when = session.state === "done" ? session["for"] + " ago" : "for " + session["for"];
    return what + (session.state === "ready" ? "" : " " + when) + "  ·  " + session.place;
  }

  // Per-day burn, from desktop-agent-tokens: the dates, and every agent with anything in them.
  property var tokenDates: []
  property var tokenAgents: []
  // One scale for every agent's chart, so their columns can be compared with each other.
  readonly property real tokenMax: {
    var most = 0;
    for (var a = 0; a < tokenAgents.length; a++)
      for (var d = 0; d < tokenAgents[a].days.length; d++)
        most = Math.max(most, tokenAgents[a].days[d].burned);
    return most;
  }

  // Green with plenty left, red when it is gone, the same scale the bar draws its two
  // figures in. This was two tones once, noticed or not, and that said nothing about the
  // long stretch in between -- which is where the decision to slow down gets made.
  function tone(severity, percent) {
    return severity === "critical" ? Color.popupUrgent : Color.gauge(percent / 100);
  }

  // The same thresholds desktop-agent-tokens and desktop-status-claude print with, so a
  // figure reads the same here as it does in a terminal.
  function compact(value) {
    var steps = [[1e9, "G"], [1e6, "M"], [1e3, "k"]];
    for (var i = 0; i < steps.length; i++)
      if (value >= steps[i][0])
        return (value / steps[i][0]).toFixed(1) + steps[i][1];
    return String(value);
  }

  // "2026-09-14" as a local date. new Date() on the bare string would read it as UTC
  // midnight, which west of Greenwich is the day before.
  function localDate(iso) {
    var parts = iso.split("-");
    return new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
  }

  function dayInitial(iso, isToday) {
    return isToday ? "today" : localDate(iso).toLocaleDateString(Qt.locale("en_GB"), "ddd").slice(0, 2);
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
          // "1 waiting for you -- 2 claude, 1 codex" when something is waiting.
          var summary = String(data.tooltip || "");
          var cut = summary.indexOf(" -- ");
          if (cut >= 0)
            summary = summary.slice(cut + 4);
          root.agents = (data.text === "") ? [] : summary.split(", ");
        } catch (e) {
          root.agents = [];
        }
      }
    }
  }

  Process {
    id: sessionProbe

    command: ["desktop-agent-sessions", "--json"]

    function reload() {
      if (!running)
        running = true;
    }

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var data = JSON.parse(text);
          root.sessions = data.sessions || [];
          root.waitingCount = data.waiting || 0;
        } catch (e) {
          root.sessions = [];
          root.waitingCount = 0;
        }
      }
    }
  }

  // States change by the second while an agent works, and reading them is a handful of
  // small files, so this one polls faster than the usage report -- only while open.
  Timer {
    interval: 3000
    repeat: true
    running: root.visible
    triggeredOnStart: true
    onTriggered: sessionProbe.reload()
  }

  Process {
    id: tokenReport

    command: ["desktop-agent-tokens", "--json"]

    function reload() {
      if (!running)
        running = true;
    }

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var data = JSON.parse(text);
          root.tokenDates = data.days || [];
          // An agent is only worth a chart if it did something this week. One that is
          // installed but idle would be seven empty stubs saying nothing.
          root.tokenAgents = (data.agents || []).filter(function (agent) {
            return agent.days.some(function (day) { return day.burned > 0; });
          });
        } catch (e) {
          root.tokenAgents = [];
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
      tokenReport.reload();
      if (!sayStatus.running)
        sayStatus.running = true;
      if (!voiceList.running)
        voiceList.running = true;
    }
  }

  contentWidth: Style.popupWidth
  contentHeight: column.implicitHeight + Style.popupPadding * 2

  Column {
    id: column

    width: parent.width
    spacing: 2

    // The fullest limit, big: the bar shows the same number, and the meters below say
    // which limit it is and when it resets. Sessions waiting on you come first in the
    // status line, since they are the thing to act on.
    PanelHero {
      readonly property var fullest: {
        var top = null;
        for (var i = 0; i < root.limits.length; i++)
          if (!top || root.limits[i].percent > top.percent)
            top = root.limits[i];
        return top;
      }

      icon: "\u{f1049}"
      iconColor: root.waitingCount > 0 ? Color.popupUrgent : Color.popupText
      title: "Claude Code"
      status: {
        var parts = [];
        if (root.waitingCount > 0)
          parts.push(root.waitingCount + " waiting for you");
        else if (root.sessions.length > 0)
          parts.push(root.sessions.length + (root.sessions.length === 1 ? " session" : " sessions"));
        if (root.plan !== "")
          parts.push(root.plan + " plan");
        if (!root.available)
          parts.push("limits unavailable");
        return parts.join("  ·  ");
      }
      statusColor: root.waitingCount > 0 ? Color.popupUrgent : Color.popupMuted
      value: fullest ? fullest.percent + "%" : "—"
      valueColor: fullest ? root.tone(fullest.severity, fullest.percent) : Color.popupMuted
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
        fillColor: root.spend ? root.tone(root.spend.severity, root.spend.percent) : Color.good
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

    PanelSection {
      title: "Last 7 days"
      value: "burned, local"
      rule: true
      visible: root.tokenAgents.length > 0
    }

    Repeater {
      model: root.tokenAgents

      delegate: Item {
        id: agentWeek

        required property var modelData
        readonly property var days: modelData.days
        readonly property int shown: chart.hoverIndex >= 0 ? chart.hoverIndex : days.length - 1
        readonly property var day: days[shown]

        width: column.width
        height: agentName.implicitHeight + dayDetail.implicitHeight + chart.implicitHeight + 20

        readonly property real week: {
          var total = 0;
          for (var i = 0; i < days.length; i++)
            total += days[i].burned;
          return total;
        }

        Text {
          id: agentName

          anchors.left: parent.left
          anchors.leftMargin: 6
          anchors.top: parent.top
          anchors.topMargin: 4
          text: agentWeek.modelData.name
          color: Color.popupText
          font.family: Style.fontFamily
          font.pixelSize: Style.fontSize
        }

        Text {
          anchors.right: parent.right
          anchors.rightMargin: 6
          anchors.baseline: agentName.baseline
          text: "week " + root.compact(agentWeek.week)
          color: Color.popupMuted
          font.family: Style.fontFamily
          font.pixelSize: Style.fontSize - 2
        }

        // Today by default, the day under the pointer while hovering. On its own line: beside
        // the name it ran into it. Cache reads are only spelled out here, never added into the
        // columns -- they are most of the raw count at a fraction of the price.
        Text {
          id: dayDetail

          anchors.left: parent.left
          anchors.leftMargin: 6
          anchors.right: parent.right
          anchors.rightMargin: 6
          anchors.top: agentName.bottom
          anchors.topMargin: 2
          elide: Text.ElideRight
          text: (chart.hoverIndex >= 0
              ? root.localDate(agentWeek.day.date).toLocaleDateString(Qt.locale("en_GB"), "ddd d")
              : "Today")
            + "  " + root.compact(agentWeek.day.burned) + " burned"
            + "  ·  " + root.compact(agentWeek.day.cache_read) + " read from cache"
          color: Color.popupMuted
          font.family: Style.fontFamily
          font.pixelSize: Style.fontSize - 2
        }

        PanelDayBars {
          id: chart

          anchors.left: parent.left
          anchors.leftMargin: 6
          anchors.right: parent.right
          anchors.rightMargin: 6
          anchors.top: dayDetail.bottom
          anchors.topMargin: 8
          maxValue: root.tokenMax
          values: agentWeek.days.map(function (d) { return d.burned; })
          labels: root.tokenDates.map(function (iso, i) {
            return root.dayInitial(iso, i === root.tokenDates.length - 1);
          })
        }
      }
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
      value: root.waitingCount > 0 ? root.waitingCount + " waiting"
        : (root.sessions.length > 0 || root.agents.length > 0) ? "running" : "idle"
      rule: true
    }

    PanelRow {
      icon: root.speaking ? "\u{f057e}" : "\u{f0581}"
      label: "Say it out loud"
      sublabel: !root.speaking ? "Off  ·  an agent that needs you is only shown"
        : root.voice === "piper" ? "On  ·  quiet during calls, dictation and do-not-disturb"
        : "On, with the fallback voice  ·  desktop-say --setup installs the better one"
      active: root.speaking
      onClicked: if (!sayToggle.running)
        sayToggle.running = true
    }

    PanelRow {
      visible: root.speaking && root.voice === "piper" && root.voices.length > 0
      icon: "\u{f0a36}"
      label: "Voice"
      sublabel: (root.voiceLabel !== "" ? root.voiceLabel : "default") + "  ·  " + (root.choosingVoice ? "pick one to hear it" : "click to change")
      onClicked: root.choosingVoice = !root.choosingVoice
    }

    Repeater {
      model: (root.choosingVoice && root.speaking) ? root.voices : []

      delegate: PanelRow {
        required property var modelData

        icon: modelData.current ? "\u{f012c}" : (modelData.installed ? "\u{f0a36}" : "\u{f01da}")
        label: modelData.label
        sublabel: root.fetching === modelData.name ? (modelData.installed ? "Listen…" : "Downloading " + modelData.megabytes + " MB…")
          : modelData.current ? "In use" : (modelData.installed ? "Click to use" : modelData.megabytes + " MB to download")
        active: modelData.current
        enabled: root.fetching === ""
        onClicked: root.chooseVoice(modelData.name)
      }
    }

    Repeater {
      model: root.sessions

      delegate: PanelRow {
        required property var modelData

        icon: root.sessionIcon(modelData.state)
        label: modelData.project
        sublabel: root.sessionText(modelData)
        // Waiting is the state worth drawing the eye to; the rest are information.
        active: modelData.state === "waiting"
        // Clickable only while its pane still exists to jump to.
        enabled: !!modelData.target
        onClicked: {
          root.close();
          Quickshell.execDetached(root.launch(["desktop-menu-agents", "--jump", modelData.target, modelData.socket]));
        }
      }
    }

    PanelRow {
      icon: "\u{f1049}"
      label: root.unreportedClaude + " claude " + (root.unreportedClaude === 1 ? "session" : "sessions")
      sublabel: "idle, no state reported yet"
      enabled: false
      visible: root.unreportedClaude > 0
    }

    Repeater {
      model: root.otherAgents

      delegate: PanelRow {
        required property var modelData

        icon: "\u{f1049}"
        label: modelData
        sublabel: "running  ·  reports no state"
        enabled: false
      }
    }

    PanelRow {
      icon: "\u{f1049}"
      label: "Nothing running"
      enabled: false
      visible: root.sessions.length === 0 && root.agents.length === 0
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
