import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui

// News: the headlines, under a heading each -- technology, the world. The first site of a
// heading is drawn wide and the rest a card each. From desktop-dash news, which reads
// each site's own feed; a headline opens in the browser.
//
// The page is laid out to fit what is left of the window and no more: two rows of cards,
// each as tall as half the room, with the headlines that do not fit scrolling inside
// their own card. A page of news that runs off the bottom of the screen is one where the
// last site is never read.
ColumnLayout {
  id: page

  property var info: null
  property bool active: false
  // How much of the window is left for this page, which the dashboard knows and this does not.
  property real room: 700
  // Ticks so "12m" becomes "13m" while the page is being read.
  property double clock: Date.now()

  // Which heading is on show, by its place in `headings`.
  property int section: 0

  spacing: Style.sectionSpacing * 2

  readonly property var all: info && info.feeds ? info.feeds : []
  // The headings in the order they first appear.
  readonly property var headings: {
    var seen = [];
    for (var i = 0; i < all.length; i++) {
      var name = all[i].category || "tech";
      if (seen.indexOf(name) === -1)
        seen.push(name);
    }
    return seen;
  }
  readonly property var feeds: {
    var want = headings[section];
    return all.filter(function (feed) {
      return (feed.category || "tech") === want;
    });
  }

  // Asked for by the dashboard's keys: the next heading, or the one before.
  function step(delta) {
    if (headings.length > 0)
      section = (section + delta + headings.length) % headings.length;
  }

  // And by name, for a voice or a script. Asked for before the headlines have arrived --
  // the tab not opened yet today -- the name is kept, and honoured when they do.
  property string wanted: ""

  function choose(name) {
    var at = headings.indexOf(name);
    if (at === -1) {
      if (headings.length > 0)
        return false;
      wanted = name;
      return true;
    }
    wanted = "";
    section = at;
    return true;
  }

  onHeadingsChanged: {
    if (wanted !== "" && headings.indexOf(wanted) !== -1) {
      section = headings.indexOf(wanted);
      wanted = "";
    } else if (section >= headings.length) {
      section = 0;
    }
  }

  readonly property int columns: width > 1500 ? 3 : 2
  // The first site is drawn two places wide when that still leaves everything in two
  // rows -- five sites or fewer on a wide screen. With six it would push the last one into
  // a third row and off the page, so then it is told apart by its colour alone.
  readonly property bool wideLead: feeds.length + 1 <= columns * 2
  readonly property int rows: Math.max(1, Math.ceil((feeds.length + (wideLead && feeds.length > 0 ? 1 : 0)) / columns))
  // Every row is on the page: the room is shared between however many there are.
  readonly property real cardHeight: {
    var used = strip.implicitHeight + page.spacing + (notice.visible ? notice.implicitHeight + page.spacing : 0);
    var each = (room - used - Style.overviewSpacing * (rows - 1)) / rows;
    return Math.max(Style.rowHeight * 3, Math.floor(each));
  }

  Timer {
    interval: 60000
    repeat: true
    running: page.active
    onTriggered: page.clock = Date.now()
  }

  function ago(at) {
    if (!at)
      return "";
    var minutes = Math.max(0, Math.floor((clock / 1000 - at) / 60));
    if (minutes < 1)
      return "now";
    if (minutes < 60)
      return minutes + "m";
    var hours = Math.floor(minutes / 60);
    return hours < 24 ? hours + "h" : Math.floor(hours / 24) + "d";
  }

  function title(name) {
    return name === "tech" ? "Technology" : name.charAt(0).toUpperCase() + name.slice(1);
  }

  function read(link) {
    // Only what the reader already vetted as an http address reaches here; it is handed
    // over as an argument, never through a shell.
    if (link)
      Quickshell.execDetached(["xdg-open", link]);
  }

  Unconnected {
    id: notice

    visible: !!page.info && page.info.connected === false
    how: page.info && page.info.how ? page.info.how : []
  }

  // The headings, as a second and smaller row of tabs.
  Row {
    id: strip

    spacing: Style.sectionSpacing

    Repeater {
      model: page.headings

      delegate: Rectangle {
        id: pill

        required property var modelData
        required property int index

        readonly property bool chosen: page.section === index

        width: name.implicitWidth + Style.popupPadding * 2
        height: name.implicitHeight + Style.sectionSpacing
        radius: height / 2
        color: chosen ? Color.popupSelected : (over.containsMouse ? Color.popupHover : "transparent")
        border.width: 1
        border.color: chosen ? Color.popupAccent : Color.popupBorder

        Behavior on color {
          ColorAnimation {
            duration: Style.motionQuick
          }
        }

        Text {
          id: name

          anchors.centerIn: parent
          text: page.title(pill.modelData)
          color: pill.chosen ? Color.popupText : Color.popupMuted
          font.family: Style.fontFamily
          font.pixelSize: Style.fontSize + 1
          font.weight: pill.chosen ? Style.barLabelWeight : Font.Normal
        }

        MouseArea {
          id: over

          anchors.fill: parent
          hoverEnabled: true
          onClicked: page.section = pill.index
        }
      }
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      leftPadding: Style.sectionSpacing
      text: "↑ ↓ to change  ·  wheel, bar or arrows scroll a card"
      color: Color.popupBorder
      font.family: Style.fontFamily
      font.pixelSize: Style.fontSize - 2
    }
  }

  GridLayout {
    Layout.fillWidth: true
    columns: page.columns
    columnSpacing: Style.overviewSpacing
    rowSpacing: Style.overviewSpacing

    Repeater {
      model: page.feeds

      delegate: Card {
        id: feed

        required property var modelData
        required property int index

        // The first one of a heading is the one it leads with, and gets the room.
        readonly property bool lead: index === 0

        order: index
        // Changing heading sets the cards arriving again, as changing tab does.
        appear: page.active
        fixedHeight: page.cardHeight
        Layout.preferredHeight: page.cardHeight
        Layout.columnSpan: lead && page.wideLead ? Math.min(2, page.columns) : 1
        icon: lead ? "\u{f0395}" : "\u{f046b}"
        title: modelData.name
        figure: modelData.ok ? "" : "—"
        tone: lead ? Color.popupAccent : Color.popupText

        Repeater {
          model: feed.modelData.items

          delegate: PanelRow {
            required property var modelData

            width: parent.width
            label: modelData.title
            sublabel: page.ago(modelData.at)
            onClicked: page.read(modelData.link)
          }
        }
        Quiet {
          visible: !feed.modelData.ok
          text: feed.modelData.site + " did not answer."
        }
      }
    }
  }
}
