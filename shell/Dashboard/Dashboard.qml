import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import qs.Ui
import "../Commons/holidays.js" as Holidays

// The dashboard: one screen of what needs you, on a workspace of its own.
//
// Every one of these has a panel, and every panel has to be opened to be read. This is
// the place they are all already open -- what the day is started on, and what is gone
// back to when the question is "is anything waiting for me?". The login leaves the focus
// here (see desktop-workspace-start), on workspace 6.
//
// A window, not a layer: it lives on a workspace like any application, so the workspace
// keys, the overview and the bar all treat it as one, and anything else can share the
// workspace with it. A window rule in default/hypr/apps/desktop-shell.conf puts it on 6.
//
// It has a tab for each subject -- start, domotics, infrastructure, health, money, what is
// being watched, and the news -- and room for more: a tab is one entry in `tabs` below, one page
// in this directory, and one answer from desktop-dash. The pages only draw. What they draw
// comes from `desktop-dash <tab> --json`, so a subject gets a new source without anything
// here changing, and a page whose source is not connected says so across its top and shows
// sample data underneath rather than nothing.
//
// The clock, the greeting and the voice sit above the tabs and stay there on every one:
// whichever subject is open, the desktop can be spoken to and seen answering.
Item {
  id: root

  readonly property int workspace: 6

  // One entry a subject. `key` is what desktop-dash is asked for; `every` is how often it
  // is asked again while that tab is being looked at, in seconds.
  readonly property var tabs: [
    {
      key: "start",
      label: "Start",
      glyph: "\u{f02dc}",
      every: 30
    },
    {
      // The key stays "home" -- it is the name of the config file and of what desktop-dash
      // is asked for -- while the tab is called what it is about.
      key: "home",
      label: "Domotics",
      glyph: "\u{f050f}",
      every: 30
    },
    {
      key: "infra",
      label: "Infrastructure",
      glyph: "\u{f048b}",
      every: 120
    },
    {
      key: "health",
      label: "Health",
      glyph: "\u{f02d1}",
      every: 600
    },
    {
      key: "finance",
      label: "Finance",
      glyph: "\u{f0116}",
      every: 600
    },
    {
      key: "watch",
      label: "Watching",
      glyph: "\u{f0208}",
      every: 1800
    },
    {
      key: "news",
      label: "News",
      glyph: "\u{f0395}",
      every: 900
    }
  ]

  property int current: 0
  // What each tab last answered, by key. Kept when leaving a tab, so coming back shows
  // what was there at once and then what is there now.
  property var answers: ({})
  property date now: new Date()
  property bool shown: true

  readonly property var brief: answers["start"] || null
  // On a screen, not focused: with more than one monitor the focused workspace follows
  // the pointer, so asking for focus emptied the page each time the mouse left the
  // laptop's screen and filled it again on the way back -- while it was in plain view
  // the whole time.
  readonly property bool lookedAt: {
    var monitors = Hyprland.monitors.values;
    for (var i = 0; i < monitors.length; i++) {
      var shownThere = monitors[i].activeWorkspace;
      if (shownThere !== null && shownThere.id === root.workspace)
        return true;
    }
    return false;
  }

  function toggle() {
    shown = !shown;
    return shown;
  }

  function go(index) {
    current = (index + tabs.length) % tabs.length;
  }

  // Asked for by desktop-voice and by scripts: "home", "watch", ...
  function show(key) {
    for (var i = 0; i < tabs.length; i++)
      if (tabs[i].key === key) {
        current = i;
        return true;
      }
    return false;
  }

  // A heading of the News tab by name, for the same callers.
  function newsSection(name) {
    refresh("news");
    return news.choose(name);
  }

  // One command at a time, for whichever tab wants asking: the tab on show first, and the
  // start tab always, since the line under the clock is its.
  property var asking: []

  function refresh(key) {
    if (asking.indexOf(key) === -1)
      asking = asking.concat([key]);
    next();
  }

  function next() {
    if (probe.running || asking.length === 0)
      return;
    probe.key = asking[0];
    probe.command = ["desktop-dash", probe.key, "--json"];
    probe.running = true;
  }

  Process {
    id: probe

    property string key: ""

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var answer = JSON.parse(text);
          var all = {};
          for (var k in root.answers)
            all[k] = root.answers[k];
          all[probe.key] = answer;
          root.answers = all;
        } catch (error) {
          // An answer that could not be read leaves the last one on screen.
        }
      }
    }
    onExited: {
      root.asking = root.asking.filter(function (k) {
        return k !== probe.key;
      });
      root.next();
    }
  }

  onCurrentChanged: refresh(tabs[current].key)
  onLookedAtChanged: if (lookedAt) {
    refresh("start");
    refresh(tabs[current].key);
  }
  Component.onCompleted: refresh("start")

  // Asked again while it is being looked at, each tab at its own pace. Not otherwise:
  // an asking is commands, the network, git on every task.
  Timer {
    interval: root.tabs[root.current].every * 1000
    repeat: true
    running: root.lookedAt && root.shown
    onTriggered: root.refresh(root.tabs[root.current].key)
  }
  Timer {
    interval: 30000
    repeat: true
    running: root.lookedAt && root.shown && root.current !== 0
    onTriggered: root.refresh("start")
  }

  Timer {
    interval: 1000
    repeat: true
    running: root.lookedAt && root.shown
    triggeredOnStart: true
    onTriggered: root.now = new Date()
  }

  function greeting() {
    var hour = now.getHours();
    var words = hour < 6 ? "Good night" : hour < 12 ? "Good morning" : hour < 18 ? "Good afternoon" : "Good evening";
    return brief && brief.user ? words + ", " + brief.user : words;
  }

  readonly property string headline: {
    if (!brief)
      return "Looking…";
    if (brief.agents.waiting > 0)
      return brief.agents.waiting + (brief.agents.waiting === 1 ? " agent is" : " agents are") + " waiting for you";
    if (brief.attention > 0)
      return brief.attention + (brief.attention === 1 ? " thing needs" : " things need") + " you";
    return "Nothing needs you";
  }

  // What the voice is doing, in a word, for beside its picture.
  readonly property string voiceState: Speech.listening ? "Listening" : Speech.state === "speaking" ? "Speaking" : Speech.state === "preparing" ? "One moment" : "Here"
  readonly property string voiceLine: Speech.active && Speech.line !== "" ? Speech.line : "Super + C, say what you want done, Super + C again"

  FloatingWindow {
    id: window

    title: "Dashboard"
    visible: root.shown
    color: Color.barBackground
    implicitWidth: 1500
    implicitHeight: 900

    Flickable {
      id: scroll

      anchors.fill: parent
      anchors.margins: Style.dashboardMargin
      contentHeight: page.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      focus: true

      // The tabs by number, and from one to the next. Plain keys: on this workspace
      // there is nothing else for them to be typed into.
      Keys.onPressed: event => {
        if (event.key >= Qt.Key_1 && event.key < Qt.Key_1 + root.tabs.length) {
          root.go(event.key - Qt.Key_1);
        } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L || event.key === Qt.Key_Tab) {
          root.go(root.current + 1);
        } else if (event.key === Qt.Key_Left || event.key === Qt.Key_H || event.key === Qt.Key_Backtab) {
          root.go(root.current - 1);
        } else if ((event.key === Qt.Key_Down || event.key === Qt.Key_J) && root.tabs[root.current].key === "news") {
          // A tab with headings of its own: down and up go through them.
          news.step(1);
        } else if ((event.key === Qt.Key_Up || event.key === Qt.Key_K) && root.tabs[root.current].key === "news") {
          news.step(-1);
        } else if (event.key === Qt.Key_R) {
          root.refresh(root.tabs[root.current].key);
        } else {
          return;
        }
        event.accepted = true;
      }

      ColumnLayout {
        id: page

        width: scroll.width
        spacing: Style.overviewSpacing

        // --- above the tabs, on every one of them --------------------------------------

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.overviewSpacing

          // What time it is and whether anything is waiting: the two things looked for
          // first, large enough to be read from the door.
          Text {
            text: Qt.formatDateTime(root.now, "HH:mm")
            color: Color.popupText
            font.family: Style.fontFamily
            font.pixelSize: Style.dashboardClockSize
            font.weight: Font.Light
          }

          ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            spacing: 4

            Text {
              Layout.fillWidth: true
              elide: Text.ElideRight
              text: root.greeting() + "  ·  " + root.headline
              color: root.brief && root.brief.attention > 0 ? Color.popupAccent : Color.popupText
              font.family: Style.fontFamily
              font.pixelSize: Style.fontSize + 7
              font.weight: Style.barLabelWeight
            }
            Text {
              text: Qt.formatDateTime(root.now, "dddd d MMMM yyyy") + "  ·  week " + Dates.isoWeek(root.now)
              color: Color.popupMuted
              font.family: Style.fontFamily
              font.pixelSize: Style.fontSize + 2
            }
          }

          // The desktop's voice, where it can be seen: the same thing that sits small in
          // the corner of every other workspace, here as large as the clock. It idles
          // when there is nothing to say, turns red while it is listening to you, and
          // beats while it speaks -- with what it is saying, or was told, beside it.
          Rectangle {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            implicitHeight: Style.dashboardOrbSize + Style.popupPadding * 2
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
              id: presence

              anchors.left: parent.left
              anchors.leftMargin: Style.popupPadding * 2
              anchors.verticalCenter: parent.verticalCenter
              width: Style.dashboardOrbSize
              height: width
              awake: Speech.active
              lively: Speech.lively
              listening: Speech.listening
              // It repaints many times a second; only while this workspace is in front.
              running: root.lookedAt && root.shown
            }

            Column {
              anchors.left: presence.right
              anchors.leftMargin: Style.popupPadding * 2
              anchors.right: parent.right
              anchors.rightMargin: Style.popupPadding * 2
              anchors.verticalCenter: parent.verticalCenter
              spacing: 6

              Text {
                text: root.voiceState
                color: Speech.listening ? Color.popupUrgent : (Speech.active ? Color.popupAccent : Color.popupMuted)
                font.family: Style.fontFamily
                font.pixelSize: Style.fontSize
                font.weight: Style.barLabelWeight
                font.capitalization: Font.AllUppercase
              }
              Text {
                width: parent.width
                text: root.voiceLine
                textFormat: Text.PlainText
                color: Speech.active ? Color.popupText : Color.popupMuted
                font.family: Style.fontFamily
                font.pixelSize: Speech.active ? Style.fontSize + 6 : Style.fontSize + 2
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight

                Behavior on font.pixelSize {
                  NumberAnimation {
                    duration: Style.motionQuick
                  }
                }
              }
            }
          }
        }

        // --- the tabs -------------------------------------------------------------------

        Item {
          id: strip

          Layout.fillWidth: true
          implicitHeight: buttons.implicitHeight + 8

          Row {
            id: buttons

            spacing: Style.sectionSpacing

            Repeater {
              model: root.tabs

              delegate: Rectangle {
                id: button

                required property var modelData
                required property int index

                readonly property bool chosen: root.current === index
                // A tab that has something to say about itself says it with a dot: the
                // start tab when something needs you, watching when something is behind.
                readonly property bool flagged: {
                  var answer = root.answers[modelData.key];
                  if (!answer)
                    return false;
                  if (modelData.key === "start")
                    return answer.attention > 0;
                  if (modelData.key === "watch")
                    return answer.behind > 0;
                  if (modelData.key === "infra")
                    return answer.trouble > 0;
                  return false;
                }

                width: label.implicitWidth + Style.popupPadding * 2
                height: label.implicitHeight + Style.popupPadding
                radius: Style.radius
                color: over.containsMouse && !chosen ? Color.popupHover : "transparent"

                Behavior on color {
                  ColorAnimation {
                    duration: Style.motionQuick
                  }
                }

                Row {
                  id: label

                  anchors.centerIn: parent
                  spacing: 8

                  Text {
                    text: button.modelData.glyph
                    color: button.chosen ? Color.popupAccent : Color.popupMuted
                    font.family: Style.fontFamily
                    font.pixelSize: Style.iconSize + 2
                  }
                  Text {
                    text: button.modelData.label
                    color: button.chosen ? Color.popupText : Color.popupMuted
                    font.family: Style.fontFamily
                    font.pixelSize: Style.fontSize + 2
                    font.weight: button.chosen ? Style.barLabelWeight : Font.Normal
                  }
                  Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: button.flagged
                    width: 7
                    height: 7
                    radius: 3.5
                    color: button.modelData.key === "infra" ? Color.popupUrgent : Color.caution
                  }
                  Text {
                    text: String(button.index + 1)
                    color: Color.popupBorder
                    font.family: Style.fontFamily
                    font.pixelSize: Style.fontSize - 2
                  }
                }

                MouseArea {
                  id: over

                  anchors.fill: parent
                  hoverEnabled: true
                  onClicked: root.go(button.index)
                }
              }
            }
          }

          // The line under the tab you are on, which slides to the next one -- the same
          // gesture the workspaces make in the bar.
          Rectangle {
            readonly property Item target: buttons.children[root.current] || null

            y: strip.height - height
            height: Style.barWorkspaceIndicatorHeight + 1
            radius: height / 2
            color: Color.popupAccent
            x: target ? target.x + Style.popupPadding : 0
            width: target ? Math.max(0, target.width - Style.popupPadding * 2) : 0

            Behavior on x {
              NumberAnimation {
                duration: Style.motionEnter
                easing.type: Easing.OutCubic
              }
            }
            Behavior on width {
              NumberAnimation {
                duration: Style.motionEnter
                easing.type: Easing.OutCubic
              }
            }
          }

          Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: Color.popupBorder
            z: -1
          }
        }

        // --- the page on show -----------------------------------------------------------
        //
        // All of them exist; one is shown. Showing is what sets a page's cards arriving,
        // one after another, so changing tab is a page settling into place and not a cut.

        Item {
          id: holder

          Layout.fillWidth: true
          implicitHeight: {
            var shown = pages.children[root.current];
            return shown ? shown.implicitHeight : 0;
          }

          Item {
            id: pages

            anchors.fill: parent

            StartPage {
              width: parent.width
              visible: root.current === 0
              active: root.current === 0 && root.lookedAt
              info: root.answers["start"] || null
              now: root.now
            }
            HomePage {
              width: parent.width
              visible: root.current === 1
              active: root.current === 1 && root.lookedAt
              info: root.answers["home"] || null
            }
            InfraPage {
              width: parent.width
              visible: root.current === 2
              active: root.current === 2 && root.lookedAt
              info: root.answers["infra"] || null
            }
            HealthPage {
              width: parent.width
              visible: root.current === 3
              active: root.current === 3 && root.lookedAt
              info: root.answers["health"] || null
            }
            FinancePage {
              width: parent.width
              visible: root.current === 4
              active: root.current === 4 && root.lookedAt
              info: root.answers["finance"] || null
            }
            WatchPage {
              width: parent.width
              visible: root.current === 5
              active: root.current === 5 && root.lookedAt
              info: root.answers["watch"] || null
            }
            NewsPage {
              id: news

              // What is left of the window under the tabs: this page fits itself to it.
              room: scroll.height - holder.y
              width: parent.width
              visible: root.current === 6
              active: root.current === 6 && root.lookedAt
              info: root.answers["news"] || null
            }
          }
        }
      }
    }
  }
}
