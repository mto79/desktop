import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui

// AI: the assistant itself, and what passes between you and it.
//
// Three headings. "Presence" is the voice drawn as large as the page allows, with what it
// is doing and who would hear a sentence the list does not know. "Voice commands" is
// what it has learned to understand, what it could not make out, and your own phrases --
// each to be kept, corrected or thrown out. "Prompts" is everything you typed to a
// coding agent: Claude Code, opencode and Codex each keep that in a place of their own,
// and desktop-dash ai reads the three into one list.
//
// Like the news it fits itself to the window: a long list scrolls inside its card.
ColumnLayout {
  id: page

  property var info: null
  // The agents' statistics, asked separately and more often than the prompts.
  property var stats: null
  property bool active: false
  // What is left of the window under the tabs.
  property real room: 700
  property double clock: Date.now()

  readonly property var headings: ["presence", "agents", "voice", "prompts"]
  readonly property var titles: ({
      "presence": "Presence",
      "agents": "Agents",
      "voice": "Voice commands",
      "prompts": "Prompts"
    })
  property int section: 0
  readonly property string heading: headings[section]

  // Which agent's prompts: "" for all of them.
  property string agent: ""

  spacing: Style.sectionSpacing * 2

  function step(delta) {
    section = (section + delta + headings.length) % headings.length;
  }

  function choose(name) {
    var at = headings.indexOf(name);
    if (at === -1)
      return false;
    section = at;
    return true;
  }

  // The room under the row of headings, for whichever of the three is showing.
  readonly property real below: Math.max(Style.rowHeight * 6, room - strip.implicitHeight - spacing)

  readonly property var agents: info && info.agents ? info.agents : []
  // The prompts of the agent chosen, or of all of them together, newest first. Not every
  // one there is: a list of two thousand rows is nothing anybody reads.
  readonly property var prompts: {
    var out = [];
    for (var i = 0; i < agents.length; i++) {
      if (agent !== "" && agents[i].key !== agent)
        continue;
      var theirs = agents[i].prompts || [];
      for (var j = 0; j < theirs.length; j++)
        out.push({
          agent: agents[i].name,
          key: agents[i].key,
          at: theirs[j].at,
          project: theirs[j].project || "",
          model: theirs[j].model || "",
          text: theirs[j].text
        });
    }
    out.sort(function (a, b) {
      return b.at - a.at;
    });
    return out.slice(0, 150);
  }

  // --- agents: what the rows and the numbers are said with ------------------------------
  function stateText(session) {
    var what = {
      "waiting": "waiting for you",
      "working": "working",
      "done": "finished",
      "ready": "open"
    }[session.state] || session.state || "open";
    return session["for"] ? what + "  ·  " + session["for"] : what;
  }

  function stateGlyph(state) {
    return state === "waiting" ? "\u{f0026}" : state === "done" ? "\u{f012c}" : state === "working" ? "\u{f06a9}" : "\u{f0765}";
  }

  function jump(target, socket) {
    if (target)
      Quickshell.execDetached(["desktop-menu-agents", "--jump", target, socket || ""]);
  }

  // 1234567 as "1.2M": a count of tokens is read for its size, not its digits.
  function compact(amount) {
    var n = Number(amount) || 0;
    if (n >= 1e9)
      return (n / 1e9).toFixed(1) + "G";
    if (n >= 1e6)
      return (n / 1e6).toFixed(1) + "M";
    if (n >= 1e3)
      return (n / 1e3).toFixed(n >= 1e5 ? 0 : 1) + "k";
    return String(Math.round(n));
  }

  function changeWords(percent, before) {
    if (!before)
      return "nothing the week before";
    return (percent > 0 ? "+" : "") + percent + "% on the week before";
  }

  function dayWords(stamp) {
    var day = new Date(stamp + "T12:00:00");
    return isNaN(day.getTime()) ? stamp : Qt.formatDate(day, "ddd d MMM");
  }

  function toneOf(key) {
    return key === "claude" ? Color.popupAccent : key === "opencode" ? Color.good : Color.caution;
  }

  function ago(at) {
    if (!at)
      return "never";
    var minutes = Math.max(0, Math.floor((clock / 1000 - at) / 60));
    if (minutes < 1)
      return "now";
    if (minutes < 60)
      return minutes + "m ago";
    var hours = Math.floor(minutes / 60);
    return hours < 24 ? hours + "h ago" : Math.floor(hours / 24) + "d ago";
  }

  Timer {
    interval: 60000
    repeat: true
    running: page.active
    onTriggered: page.clock = Date.now()
  }

  // The headings, as a second and smaller row of tabs.
  Row {
    id: strip

    spacing: Style.sectionSpacing

    Choice {
      options: page.headings.map(function (name) {
        return {
          id: name,
          label: page.titles[name]
        };
      })
      chosen: page.heading
      textSize: Style.fontSize + 1
      onPicked: id => page.choose(id)
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      leftPadding: Style.sectionSpacing
      text: "↑ ↓ to change"
      color: Color.popupBorder
      font.family: Style.fontFamily
      font.pixelSize: Style.fontSize - 2
    }
  }

  // --- presence ------------------------------------------------------------------------
  Rectangle {
    visible: page.heading === "presence"
    Layout.fillWidth: true
    implicitHeight: page.below
    radius: Style.radius
    color: Color.popupBackground
    border.width: Speech.active ? 2 : 1
    border.color: Speech.listening ? Color.popupUrgent : (Speech.active ? Color.popupAccent : Color.popupBorder)

    Behavior on border.color {
      ColorAnimation {
        duration: Style.motionEnter
      }
    }

    Orb {
      id: big

      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top
      anchors.topMargin: Style.popupPadding
      width: Math.max(160, Math.min(parent.width * 0.5, parent.height - words.implicitHeight - Style.popupPadding * 4))
      height: width
      awake: Speech.active
      lively: Speech.lively
      listening: Speech.listening
      // It repaints many times a second; only while this is what is being looked at.
      running: page.active && page.heading === "presence"
    }

    Column {
      id: words

      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: Style.popupPadding * 2
      width: Math.min(parent.width - Style.popupPadding * 4, 1100)
      spacing: Style.sectionSpacing

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Speech.listening ? "Listening" : Speech.state === "speaking" ? "Speaking" : Speech.state === "preparing" ? "One moment" : "Here"
        color: Speech.listening ? Color.popupUrgent : (Speech.active ? Color.popupAccent : Color.popupMuted)
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSize + 2
        font.weight: Style.barLabelWeight
        font.capitalization: Font.AllUppercase
      }
      Text {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: Speech.active && Speech.line !== "" ? Speech.line : "Super + C, and say what you want done"
        textFormat: Text.PlainText
        color: Speech.active ? Color.popupText : Color.popupMuted
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSize + 10
        wrapMode: Text.WordWrap
        maximumLineCount: 3
        elide: Text.ElideRight
      }
      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.popupPadding

        Choice {
          anchors.verticalCenter: parent.verticalCenter
          options: Speech.modeOptions
          chosen: Speech.modeInUse
          wanted: Speech.mode
          textSize: Style.fontSize + 1
          onPicked: id => Speech.setMode(id)
        }
        Column {
          anchors.verticalCenter: parent.verticalCenter
          spacing: 1

          Text {
            text: Speech.model !== "" ? Speech.model : "no model"
            textFormat: Text.PlainText
            color: Speech.modelTone
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSize + 2
            font.weight: Style.barLabelWeight
          }
          Text {
            text: Speech.modeNote !== "" ? Speech.modeNote : Speech.whereLine
            textFormat: Text.PlainText
            color: Color.popupMuted
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSize - 1
          }
        }
      }
    }
  }

  // --- voice commands ------------------------------------------------------------------
  // A sentence a model made sense of is kept, and known from then on without asking.
  // That is a guess kept: here it can be seen, and thrown out when it was wrong.
  GridLayout {
    visible: page.heading === "voice"
    Layout.fillWidth: true
    columns: width > 1500 ? 3 : (width > 900 ? 2 : 1)
    columnSpacing: Style.overviewSpacing
    rowSpacing: Style.overviewSpacing

    readonly property real cardHeight: columns === 3 ? page.below : Math.max(Style.rowHeight * 5, (page.below - Style.overviewSpacing) / 2)

    Card {
      order: 0
      appear: page.active && page.heading === "voice"
      icon: "\u{f03eb}"
      title: "Your own phrases"
      figure: String(Speech.yours.length)
      tone: Color.popupAccent
      fixedHeight: parent.cardHeight
      Layout.preferredHeight: parent.cardHeight

      PanelRow {
        width: parent.width
        icon: "\u{f0415}"
        label: "Add or change a phrase"
        sublabel: "phrase = command, one a line  ·  opens an editor"
        onClicked: Speech.edit("")
      }
      Repeater {
        model: Speech.yours

        delegate: PanelRow {
          required property var modelData

          width: parent.width
          icon: "\u{f0004}"
          label: "“" + modelData.phrase + "”"
          sublabel: "→ " + modelData.command
          onClicked: Speech.edit("")

          Forget {
            onChosen: Speech.forget(modelData.phrase)
          }
        }
      }
      Quiet {
        visible: Speech.yours.length === 0
        text: "None yet. A phrase of yours wins over anything learned."
      }
    }

    Card {
      order: 1
      appear: page.active && page.heading === "voice"
      icon: "\u{f1719}"
      title: "Learned"
      figure: String(Speech.learned.length)
      tone: Speech.modelTone
      fixedHeight: parent.cardHeight
      Layout.preferredHeight: parent.cardHeight

      Repeater {
        model: Speech.learned

        delegate: PanelRow {
          required property var modelData

          width: parent.width
          icon: "\u{f06a9}"
          label: "“" + modelData.phrase + "”"
          sublabel: "→ " + modelData.command + "  ·  " + modelData.by + "  ·  " + modelData.when
          // Wrong? Say what it should have been.
          onClicked: Speech.edit(modelData.phrase)

          Forget {
            onChosen: Speech.forget(modelData.phrase)
          }
        }
      }
      Quiet {
        visible: Speech.learned.length === 0
        text: "Nothing learned yet. Say something the list does not know."
      }
    }

    Card {
      order: 2
      appear: page.active && page.heading === "voice"
      icon: "\u{f02d6}"
      title: "Not understood"
      figure: String(Speech.missed.length)
      tone: Speech.missed.length > 0 ? Color.caution : Color.popupText
      fixedHeight: parent.cardHeight
      Layout.preferredHeight: parent.cardHeight

      Repeater {
        model: Speech.missed

        delegate: PanelRow {
          required property var modelData

          width: parent.width
          icon: "\u{f02d6}"
          accentColor: Color.caution
          label: "“" + modelData.phrase + "”"
          sublabel: modelData.when + "  ·  click to say what it means"
          onClicked: Speech.edit(modelData.phrase)

          Forget {
            onChosen: Speech.forget(modelData.phrase)
          }
        }
      }
      Quiet {
        visible: Speech.missed.length === 0
        text: "Nothing it could not make out."
      }
    }
  }

  // --- agents --------------------------------------------------------------------------
  GridLayout {
    id: counted

    readonly property bool on: page.active && page.heading === "agents"

    visible: page.heading === "agents"
    Layout.fillWidth: true
    columns: page.width > 1500 ? 3 : (page.width > 900 ? 2 : 1)
    columnSpacing: Style.overviewSpacing
    rowSpacing: Style.overviewSpacing

    Card {
      order: 0
      appear: counted.on
      Layout.columnSpan: counted.columns
      icon: "\u{f06a9}"
      title: "Now"
      figure: page.stats && page.stats.kinds.length > 0 ? page.stats.kinds.map(function (kind) {
        return kind.count + " " + kind.key;
      }).join("  ·  ") : ""
      tone: page.stats && page.stats.states.waiting > 0 ? Color.popupUrgent : Color.popupAccent

      Row {
        spacing: Style.overviewSpacing * 1.5
        topPadding: 6
        bottomPadding: 6

        Figure {
          appear: counted.on
          value: page.stats ? page.stats.running : 0
          label: "running"
        }
        Figure {
          appear: counted.on
          value: page.stats ? page.stats.states.working : 0
          label: "working"
          tone: Color.popupAccent
        }
        Figure {
          appear: counted.on
          value: page.stats ? page.stats.states.waiting : 0
          label: "waiting for you"
          tone: page.stats && page.stats.states.waiting > 0 ? Color.popupUrgent : Color.popupMuted
        }
        Figure {
          appear: counted.on
          value: page.stats ? page.stats.states.done : 0
          label: "finished"
          tone: Color.good
        }
        Figure {
          appear: counted.on
          value: page.stats ? page.stats.today / 1e6 : 0
          decimals: 2
          unit: "M"
          label: "tokens today"
        }
        Figure {
          appear: counted.on
          value: page.stats ? page.stats.week / 1e6 : 0
          decimals: 1
          unit: "M"
          label: "this week"
        }
        Figure {
          appear: counted.on
          value: page.stats ? page.stats.change : 0
          prefix: page.stats && page.stats.change > 0 ? "+" : ""
          unit: "%"
          label: "on the week before"
          tone: page.stats && page.stats.change > 50 ? Color.caution : Color.popupText
        }
      }
    }

    Card {
      order: 1
      appear: counted.on
      Layout.alignment: Qt.AlignTop
      icon: "\u{f06a9}"
      title: "Sessions"
      figure: page.stats ? String(page.stats.sessions.length) : ""
      tone: page.stats && page.stats.states.waiting > 0 ? Color.popupUrgent : Color.popupAccent
      fixedHeight: Style.rowHeight * 7

      Repeater {
        model: page.stats ? page.stats.sessions : []

        delegate: PanelRow {
          required property var modelData

          width: parent.width
          icon: page.stateGlyph(modelData.state)
          label: modelData.project
          sublabel: modelData.agent + "  ·  " + page.stateText(modelData)
          active: modelData.state === "waiting"
          accentColor: modelData.state === "waiting" ? Color.popupUrgent : page.toneOf(modelData.agent)
          enabled: !!modelData.target
          onClicked: page.jump(modelData.target, modelData.socket)
        }
      }
      Quiet {
        visible: !!page.stats && page.stats.sessions.length === 0
        text: "No agent is running."
      }
    }

    Card {
      order: 2
      appear: counted.on
      Layout.alignment: Qt.AlignTop
      icon: "\u{f062c}"
      title: "Tasks"
      figure: page.stats ? String(page.stats.tasks.length) : ""
      tone: Color.popupAccent
      fixedHeight: Style.rowHeight * 7

      Repeater {
        model: page.stats ? page.stats.tasks : []

        delegate: PanelRow {
          required property var modelData

          width: parent.width
          icon: page.stateGlyph(modelData.state)
          label: modelData.repo + "  ·  " + modelData.name
          sublabel: (modelData.ahead === 0 ? "nothing committed yet" : modelData.ahead + (modelData.ahead === 1 ? " commit" : " commits")) + (modelData.dirty > 0 ? "  ·  " + modelData.dirty + " uncommitted" : "")
          active: modelData.state === "waiting"
          enabled: modelData.target !== ""
          onClicked: page.jump(modelData.target, "")
        }
      }
      Quiet {
        visible: !!page.stats && page.stats.tasks.length === 0
        text: "No task is open. prefix + T in tmux starts one."
      }
    }

    Card {
      order: 3
      appear: counted.on
      Layout.alignment: Qt.AlignTop
      icon: "\u{f1719}"
      title: page.stats && page.stats.plan ? "Claude  ·  " + page.stats.plan + " plan" : "Claude"
      figure: page.stats && page.stats.limits.length > 0 ? Math.max.apply(null, page.stats.limits.map(function (l) {
        return l.percent;
      })) + "%" : ""
      tone: Color.popupAccent
      fixedHeight: Style.rowHeight * 7

      Repeater {
        model: page.stats ? page.stats.limits : []

        delegate: Column {
          id: limit

          required property var modelData

          width: parent.width
          spacing: 4
          topPadding: 6

          RowLayout {
            width: parent.width

            Text {
              Layout.fillWidth: true
              text: limit.modelData.name
              color: Color.popupText
              font.family: Style.fontFamily
              font.pixelSize: Style.fontSize
            }
            Text {
              text: limit.modelData.percent + "%  ·  resets " + limit.modelData.resets
              color: Color.popupMuted
              font.family: Style.fontFamily
              font.pixelSize: Style.fontSize - 1
            }
          }
          Rectangle {
            width: parent.width
            height: 5
            radius: height / 2
            color: Color.popupBorder

            Rectangle {
              width: Math.round(parent.width * Math.max(0, Math.min(100, limit.modelData.percent)) / 100)
              height: parent.height
              radius: parent.radius
              color: limit.modelData.percent >= 90 ? Color.popupUrgent : Color.popupAccent
            }
          }
        }
      }
      Quiet {
        visible: !!page.stats && page.stats.limits.length === 0
        text: "No usage report -- offline, or the login has expired."
      }
      Quiet {
        visible: !!page.stats && page.stats.limits.length > 0
        topPadding: 8
        text: page.stats ? "Burned in the last " + page.stats.window_hours + " hours: " + page.compact(page.stats.agents.length > 0 ? page.stats.agents[0].window : 0) + " tokens" : ""
      }
    }

    // Every agent together, a day to a bar: the shape of a month.
    Card {
      order: 4
      appear: counted.on
      Layout.columnSpan: Math.min(2, counted.columns)
      icon: "\u{f0127}"
      title: "Thirty days"
      figure: page.stats ? page.compact(page.stats.month) : ""

      Bars {
        width: parent.width
        implicitHeight: Style.rowHeight * 4
        appear: counted.on
        values: page.stats ? page.stats.days : []
        sparse: true
        highlight: page.stats ? page.stats.days.length - 1 : -1
      }
      Quiet {
        text: "Tokens burned a day by all agents: what was read new, written to the cache and answered. Today is the bright bar."
      }
    }

    Card {
      order: 5
      appear: counted.on
      icon: "\u{f0954}"
      title: "Today by the hour"
      figure: page.stats ? page.compact(page.stats.today) : ""

      Bars {
        width: parent.width
        implicitHeight: Style.rowHeight * 4
        appear: counted.on
        values: page.stats ? page.stats.hours : []
        sparse: true
        highlight: new Date(page.clock).getHours()
      }
      Quiet {
        text: "The bright bar is this hour."
      }
    }

    // One card an agent: what it used, and how that compares.
    Repeater {
      model: page.stats ? page.stats.agents : []

      delegate: Card {
        id: used

        required property var modelData
        required property int index

        order: 6 + index
        appear: counted.on
        Layout.alignment: Qt.AlignTop
        icon: "\u{f06a9}"
        title: modelData.name
        figure: page.compact(modelData.week)
        tone: page.toneOf(modelData.key)
        opacity: modelData.present ? 1 : 0.6

        Bars {
          width: parent.width
          implicitHeight: Style.rowHeight * 2.6
          appear: counted.on
          values: used.modelData.last7
          tone: page.toneOf(used.modelData.key)
          highlight: 6
        }
        Repeater {
          model: !used.modelData.present ? [] : [
            ["Today", page.compact(used.modelData.today) + "  ·  " + used.modelData.today_answers + " answers"],
            ["This week", page.compact(used.modelData.week) + "  ·  " + page.changeWords(used.modelData.change, used.modelData.before)],
            ["Thirty days", page.compact(used.modelData.month) + "  ·  " + used.modelData.active_days + " days in use"],
            ["A day in use", page.compact(used.modelData.average) + " on average"],
            ["Busiest day", used.modelData.best ? page.dayWords(used.modelData.best.date) + "  ·  " + page.compact(used.modelData.best.burned) : "none"],
            ["Per answer", used.modelData.per_answer > 0 ? page.compact(used.modelData.per_answer) + " tokens, this week" : "nothing this week"],
            ["From the cache", used.modelData.cached + "% of what it read"],
            ["Written", page.compact(used.modelData.written) + " tokens of answers"]
          ]

          delegate: RowLayout {
            required property var modelData

            width: parent ? parent.width : 0

            Text {
              text: modelData[0]
              color: Color.popupMuted
              font.family: Style.fontFamily
              font.pixelSize: Style.fontSize
            }
            Text {
              Layout.fillWidth: true
              horizontalAlignment: Text.AlignRight
              text: modelData[1]
              color: Color.popupText
              font.family: Style.fontFamily
              font.pixelSize: Style.fontSize
              elide: Text.ElideLeft
            }
          }
        }
        Quiet {
          visible: !used.modelData.present
          text: "Nothing used in thirty days."
        }
      }
    }
  }

  // --- prompts -------------------------------------------------------------------------
  GridLayout {
    id: asked

    visible: page.heading === "prompts"
    Layout.fillWidth: true
    columns: Math.max(1, page.agents.length)
    columnSpacing: Style.overviewSpacing
    rowSpacing: Style.overviewSpacing

    readonly property real statHeight: Style.rowHeight * 5.8
    readonly property real listHeight: Math.max(Style.rowHeight * 5, page.below - statHeight - Style.overviewSpacing)

    // One card an agent: how much you asked it, and when. A click keeps the list below
    // to that agent; a second click lets the others back in.
    Repeater {
      model: page.agents

      delegate: Card {
        id: stat

        required property var modelData
        required property int index

        readonly property bool chosen: page.agent === modelData.key

        order: index
        appear: page.active && page.heading === "prompts"
        icon: chosen ? "\u{f0133}" : "\u{f06a9}"
        title: modelData.name
        figure: String(modelData.total)
        tone: page.toneOf(modelData.key)
        fixedHeight: asked.statHeight
        Layout.preferredHeight: asked.statHeight

        PanelRow {
          width: parent.width
          icon: stat.chosen ? "\u{f0232}" : "\u{f0233}"
          active: stat.chosen
          accentColor: page.toneOf(stat.modelData.key)
          label: stat.modelData.today + " today  ·  " + stat.modelData.week + " this week"
          sublabel: (stat.modelData.total > 0 ? "last " + page.ago(stat.modelData.last) : "nothing asked yet") + "  ·  " + (stat.chosen ? "click to show all" : "click to show only these")
          onClicked: page.agent = stat.chosen ? "" : stat.modelData.key
        }
        Bars {
          width: parent.width
          implicitHeight: Style.rowHeight * 2
          appear: page.active && page.heading === "prompts"
          values: stat.modelData.days
          tone: page.toneOf(stat.modelData.key)
          highlight: 6
        }
      }
    }

    Card {
      order: 3
      appear: page.active && page.heading === "prompts"
      Layout.columnSpan: asked.columns
      icon: "\u{f0369}"
      title: page.agent === "" ? "Everything you asked" : "What you asked " + (page.prompts.length > 0 ? page.prompts[0].agent : "")
      figure: page.info ? String(page.info.today) + " today" : ""
      tone: page.agent === "" ? Color.popupAccent : page.toneOf(page.agent)
      fixedHeight: asked.listHeight
      Layout.preferredHeight: asked.listHeight

      Repeater {
        model: page.prompts

        delegate: PanelRow {
          required property var modelData

          width: parent.width
          icon: "\u{f06a9}"
          accentColor: page.toneOf(modelData.key)
          active: hovered
          label: modelData.text
          sublabel: modelData.agent + (modelData.model !== "" ? " (" + modelData.model + ")" : "") + (modelData.project !== "" ? "  ·  " + modelData.project : "") + "  ·  " + page.ago(modelData.at) + "  ·  click to copy"
          // Handed over as an argument, never through a shell.
          onClicked: Quickshell.execDetached(["wl-copy", "--", modelData.text])
        }
      }
      Quiet {
        visible: page.prompts.length === 0
        text: page.info ? "Nothing asked here yet." : "Reading what you asked…"
      }
    }
  }

  // The cross at the end of a row: drop this one.
  component Forget: Rectangle {
    id: cross

    signal chosen

    width: Style.rowHeight - 10
    height: width
    radius: width / 2
    color: crossArea.containsMouse ? Qt.rgba(Color.popupUrgent.r, Color.popupUrgent.g, Color.popupUrgent.b, 0.2) : "transparent"

    Text {
      anchors.centerIn: parent
      text: "\u{f0156}"
      color: crossArea.containsMouse ? Color.popupUrgent : Color.popupMuted
      font.family: Style.fontFamily
      font.pixelSize: Style.iconSize
    }

    MouseArea {
      id: crossArea

      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: cross.chosen()
    }
  }
}
