import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "../Commons/holidays.js" as Holidays

// Start: the day at a glance, on one screen. Tiles rather than lists -- a ring for a share,
// a grid for the month, a few lines for the rest -- so what wants looking at is found by
// where it sits and not by reading down a column.
//
//   system    claude    weather   month     to-do
//   screen    playing   headlines ········  to-do
//   machine   notices   headlines ········  notes
//   the dock ·······················································
//
// From desktop-dash start (desktop-brief), the News tab's own answer for the headlines, the
// media players for what is playing, and two files for the to-do list and the note
// (desktop-todo). The agents and their tasks are on the AI tab; the line under the clock
// still says when one of them is waiting.
//
// It fits what is left of the window under the tabs, `room`: five columns, three rows and
// the dock under them. On a screen too short for that the tiles keep a height they can be
// read at, and the page scrolls.
Item {
  id: page

  property var info: null
  property var news: null
  property bool active: false
  property date now: new Date()
  property real room: 800

  // Typing in the to-do or the note is over: the dashboard takes the keys back.
  signal typingDone

  readonly property real gap: 16
  readonly property int columns: 5
  readonly property real dockHeight: 84
  readonly property real columnWidth: (width - gap * (columns - 1)) / columns
  readonly property real rowHeight: Math.max(180, (room - dockHeight - gap * 3) / 3)

  implicitHeight: rowHeight * 3 + gap * 3 + dockHeight

  readonly property var screen: info && info.screentime ? info.screentime : ({ today: 0, average: 0, week: [], apps: [], since: "" })
  readonly property var system: info ? info.system : null
  readonly property var weather: info && info.weather ? info.weather : null

  function colX(column) {
    return column * (columnWidth + gap);
  }
  function rowY(row) {
    return row * (rowHeight + gap);
  }
  function wide(columns) {
    return columnWidth * columns + gap * (columns - 1);
  }
  function tall(rows) {
    return rowHeight * rows + gap * (rows - 1);
  }

  // 192 minutes as "3h 12m", 45 as "45m".
  function duration(minutes) {
    var h = Math.floor(minutes / 60), m = minutes % 60;
    return h > 0 ? h + "h " + (m < 10 ? "0" : "") + m + "m" : m + "m";
  }

  // "2 days, 7 hours, 47 minutes" as "2d 7h": uptime(1) said in the corner of a tile.
  function short(uptime) {
    return uptime.replace(/ days?/, "d").replace(/ hours?/, "h").replace(/ minutes?/, "m").replace(/,/g, "").split(" ").slice(0, 2).join(" ");
  }

  // How long ago an epoch second was, in the fewest characters: "14m", "3h", "2d".
  function ago(at) {
    var s = Math.max(0, now.getTime() / 1000 - at);
    return s < 3600 ? Math.max(1, Math.floor(s / 60)) + "m" : s < 86400 ? Math.floor(s / 3600) + "h" : Math.floor(s / 86400) + "d";
  }

  function limit(name) {
    var all = info && info.limits ? info.limits : [];
    for (var i = 0; i < all.length; i++)
      if (all[i].name === name)
        return all[i];
    return null;
  }

  // The WMO code as a glyph: sun, cloud, fog, rain, snow, storm -- the moon by night.
  function sky(code, day) {
    if (code === 0)
      return day === false ? "\u{f0594}" : "\u{f0599}";
    if (code <= 2)
      return day === false ? "\u{f0f31}" : "\u{f0595}";
    if (code === 3)
      return "\u{f0590}";
    if (code <= 48)
      return "\u{f0591}";
    if (code <= 67 || (code >= 80 && code <= 82))
      return code >= 63 && code <= 67 ? "\u{f0596}" : "\u{f0597}";
    if (code <= 77 || code <= 86)
      return "\u{f0598}";
    return "\u{f0593}";
  }

  function run(command) {
    Quickshell.execDetached(command);
  }

  // --- system: four rings ---------------------------------------------------------------
  Card {
    id: machine

    x: page.colX(0)
    y: page.rowY(0)
    width: page.columnWidth
    fixedHeight: page.rowHeight
    order: 0
    appear: page.active
    icon: "\u{f061a}"
    title: "System"
    figure: page.system ? "up " + page.short(page.system.uptime) : ""
    tone: Color.popupMuted

    Grid {
      id: rings

      readonly property real size: Math.min((machine.width - 40 - columnSpacing) / 2, (machine.inner - rowSpacing - 2) / 2)

      x: (parent.width - width) / 2
      columns: 2
      columnSpacing: 10
      rowSpacing: 8

      Ring {
        width: rings.size
        value: page.system ? page.system.cpu / 100 : 0
        text: page.system ? page.system.cpu + "%" : "–"
        label: "cpu"
        appear: page.active
      }
      Ring {
        width: rings.size
        value: page.system ? page.system.ram / 100 : 0
        text: page.system ? page.system.ram + "%" : "–"
        label: "ram"
        appear: page.active
      }
      Ring {
        width: rings.size
        // Coloured by heat: 40° is cool, 95° is as hot as a package is let get.
        value: page.system && page.system.temp !== null ? Math.max(0, (page.system.temp - 40) / 55) : 0
        text: page.system && page.system.temp !== null ? page.system.temp + "°" : "–"
        label: "temp"
        appear: page.active
      }
      Ring {
        width: rings.size
        value: page.system ? page.system.disk_used / 100 : 0
        text: page.system ? page.system.disk_used + "%" : "–"
        label: "disk"
        appear: page.active
      }
    }
  }

  // --- Claude: the session and the week ------------------------------------------------
  Card {
    id: claude

    readonly property var session: page.limit("Session")
    readonly property var week: page.limit("Weekly")

    x: page.colX(1)
    y: page.rowY(0)
    width: page.columnWidth
    fixedHeight: page.rowHeight
    order: 1
    appear: page.active
    icon: "\u{f06a9}"
    title: "Claude"
    tone: Color.popupAccent

    Row {
      readonly property real size: Math.min((claude.width - 40 - spacing) / 2, claude.inner - 4)

      x: (parent.width - width) / 2
      spacing: 16
      topPadding: Math.max(0, (claude.inner - size) / 2 - 2)

      Ring {
        width: parent.size
        value: claude.session ? claude.session.percent / 100 : 0
        text: claude.session ? claude.session.percent + "%" : "–"
        label: "session"
        detail: claude.session ? claude.session.resets : ""
        appear: page.active
      }
      Ring {
        width: parent.size
        value: claude.week ? claude.week.percent / 100 : 0
        text: claude.week ? claude.week.percent + "%" : "–"
        label: "week"
        detail: claude.week ? claude.week.resets : ""
        appear: page.active
      }
    }
  }

  // --- the weather ----------------------------------------------------------------------
  Card {
    id: weatherCard

    readonly property var w: page.weather

    x: page.colX(2)
    y: page.rowY(0)
    width: page.columnWidth
    fixedHeight: page.rowHeight
    order: 2
    appear: page.active
    icon: "\u{f0595}"
    title: w && w.connected === false ? "Weather  ·  sample" : (w && w.place ? "Weather  ·  " + w.place : "Weather")
    figure: ""
    tone: w && w.connected === false ? Color.popupMuted : Color.popupAccent

    Row {
      width: parent.width
      spacing: 14
      visible: !!weatherCard.w && !!weatherCard.w.now

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: weatherCard.w && weatherCard.w.now ? page.sky(weatherCard.w.now.code, weatherCard.w.now.day) : ""
        color: Color.popupAccent
        font.family: Style.fontFamily
        font.pixelSize: 38
      }
      Column {
        anchors.verticalCenter: parent.verticalCenter

        Text {
          text: weatherCard.w && weatherCard.w.now ? weatherCard.w.now.temp + "°" : ""
          color: Color.popupText
          font.family: Style.fontFamily
          font.pixelSize: 32
          font.weight: Style.barLabelWeight
        }
        Text {
          text: weatherCard.w && weatherCard.w.now ? weatherCard.w.now.text : ""
          color: Color.popupText
          font.family: Style.fontFamily
          font.pixelSize: Style.fontSize
        }
      }
    }
    Text {
      width: parent.width
      visible: !!weatherCard.w && !!weatherCard.w.now
      text: weatherCard.w && weatherCard.w.connected === false ? "invented: " + (weatherCard.w.how || "") : weatherCard.w && weatherCard.w.now ? "feels " + weatherCard.w.now.feels + "°  ·  " + weatherCard.w.now.humidity + "%  ·  " + weatherCard.w.now.wind + " km/h" + (weatherCard.w.sun ? "  ·  sun " + weatherCard.w.sun.rise + "–" + weatherCard.w.sun.set : "") : ""
      color: weatherCard.w && weatherCard.w.connected === false ? Color.caution : Color.popupMuted
      font.family: Style.fontFamily
      font.pixelSize: Style.fontSize - 2
      wrapMode: Text.WordWrap
      maximumLineCount: 2
      elide: Text.ElideRight
      bottomPadding: 8
    }
    Row {
      width: parent.width
      spacing: 8
      visible: !!weatherCard.w && !!weatherCard.w.days

      Repeater {
        model: weatherCard.w && weatherCard.w.days ? weatherCard.w.days : []

        delegate: Rectangle {
          required property var modelData

          width: (parent.width - 16) / 3
          height: 54
          radius: Style.radius
          color: Color.popupHover

          Column {
            anchors.centerIn: parent
            spacing: 1

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: parent.parent.modelData.day
              color: Color.popupMuted
              font.family: Style.fontFamily
              font.pixelSize: Style.fontSize - 2
            }
            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: page.sky(parent.parent.modelData.code, true)
              color: Color.popupAccent
              font.family: Style.fontFamily
              font.pixelSize: Style.iconSize + 4
            }
            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: parent.parent.modelData.max + "° / " + parent.parent.modelData.min + "°"
              color: Color.popupText
              font.family: Style.fontFamily
              font.pixelSize: Style.fontSize - 2
            }
          }
        }
      }
    }
  }

  // --- the month ------------------------------------------------------------------------
  Card {
    id: month

    // Monday first; the days before the 1st and after the last are the months either side.
    readonly property date first: new Date(page.now.getFullYear(), page.now.getMonth(), 1)
    readonly property int lead: (first.getDay() + 6) % 7
    readonly property var holidays: {
      var map = {};
      var list = Holidays.upcoming(new Date(page.now.getFullYear(), page.now.getMonth(), 1), 12);
      for (var i = 0; i < list.length; i++)
        map[Holidays.key(list[i].date)] = list[i].name;
      return map;
    }
    readonly property var next: {
      var list = Holidays.upcoming(page.now, 1);
      return list.length > 0 ? list[0] : null;
    }

    x: page.colX(3)
    y: page.rowY(0)
    width: page.columnWidth
    fixedHeight: page.rowHeight
    order: 3
    appear: page.active
    icon: "\u{f00ed}"
    title: Qt.formatDate(page.now, "MMMM yyyy")
    figure: "week " + Dates.isoWeek(page.now)
    tone: Color.popupAccent

    Grid {
      id: days

      readonly property real cell: width / 7
      readonly property real line: Math.min(cell * 0.8, (month.inner - 22) / 7)

      width: parent.width
      columns: 7

      Repeater {
        model: ["M", "T", "W", "T", "F", "S", "S"]

        delegate: Text {
          required property string modelData
          required property int index

          width: days.cell
          height: days.line
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
          text: modelData
          color: index >= 5 ? Color.popupAccent : Color.popupMuted
          font.family: Style.fontFamily
          font.pixelSize: Style.fontSize - 2
          font.weight: Style.barLabelWeight
        }
      }
      Repeater {
        model: 42

        delegate: Item {
          id: day

          required property int index

          readonly property date date: new Date(month.first.getFullYear(), month.first.getMonth(), 1 + index - month.lead)
          readonly property bool here: date.getMonth() === month.first.getMonth()
          readonly property bool today: date.toDateString() === page.now.toDateString()
          readonly property string holiday: month.holidays[Holidays.key(date)] || ""

          width: days.cell
          height: days.line

          Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height) - 2
            height: width
            radius: width / 2
            visible: day.today || day.holiday !== ""
            color: day.today ? Color.popupAccent : "transparent"
            border.width: day.holiday !== "" && !day.today ? 1 : 0
            border.color: Color.caution
          }
          Text {
            anchors.centerIn: parent
            text: day.date.getDate()
            color: day.today ? Color.popupBackground : (!day.here ? Color.popupBorder : (day.holiday !== "" ? Color.caution : Color.popupText))
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSize - 1
            font.weight: day.today ? Style.barLabelWeight : Font.Normal
          }
        }
      }
    }
    Text {
      width: parent.width
      visible: !!month.next
      topPadding: 4
      text: month.next ? month.next.name + "  ·  " + Qt.formatDate(month.next.date, "d MMM") : ""
      color: Color.caution
      font.family: Style.fontFamily
      font.pixelSize: Style.fontSize - 2
      elide: Text.ElideRight
    }
  }

  // --- to-do: two rows tall -------------------------------------------------------------
  Card {
    id: todo

    readonly property var items: todoFile.items
    readonly property int open: items.filter(function (i) {
      return !i.done;
    }).length

    x: page.colX(4)
    y: page.rowY(0)
    width: page.columnWidth
    fixedHeight: page.tall(2)
    order: 4
    appear: page.active
    icon: "\u{f0c52}"
    title: "To-do"
    figure: open > 0 ? String(open) : ""
    tone: Color.popupAccent

    PanelInput {
      id: adding

      width: parent.width
      placeholder: "+ new task"
      onAccepted: {
        if (text.trim() !== "")
          page.run(["desktop-todo", "add", text]);
        text = "";
      }
      onCancelled: {
        text = "";
        release();
        page.typingDone();
      }
    }
    Item {
      width: parent.width
      height: 6
    }
    Repeater {
      model: todo.items

      delegate: PanelRow {
        required property var modelData

        width: parent.width
        icon: modelData.done ? "\u{f0132}" : "\u{f0131}"
        label: modelData.text
        active: false
        accentColor: Color.popupAccent
        opacity: modelData.done ? 0.5 : 1
        onClicked: page.run(["desktop-todo", "done", String(modelData.id)])
        onRightClicked: page.run(["desktop-todo", "remove", String(modelData.id)])
      }
    }
    PanelRow {
      width: parent.width
      visible: todo.items.length > todo.open
      icon: "\u{f0a7a}"
      label: "Clear what is done"
      sublabel: "right-click an item to remove just that one"
      onClicked: page.run(["desktop-todo", "clear"])
    }
    Quiet {
      visible: todo.items.length === 0
      text: "Nothing to do. Type a task above and press Enter."
    }
  }

  // --- screen time ----------------------------------------------------------------------
  Card {
    x: page.colX(0)
    y: page.rowY(1)
    width: page.columnWidth
    fixedHeight: page.rowHeight
    order: 5
    appear: page.active
    icon: "\u{f0954}"
    title: "Screen time"
    figure: page.info ? page.duration(page.screen.today) : ""
    tone: Color.popupAccent

    Bars {
      width: parent.width
      implicitHeight: 84
      height: 84
      visible: page.screen.week.length > 0
      values: page.screen.week
      field: "minutes"
      highlight: page.screen.week.length - 1
      appear: page.active
    }
    Item {
      width: parent.width
      height: 6
    }
    Repeater {
      model: page.screen.apps.slice(0, 3)

      delegate: Item {
        required property var modelData

        width: parent.width
        height: Style.fontSize + 9

        Text {
          anchors.left: parent.left
          anchors.right: spent.left
          anchors.rightMargin: 8
          text: parent.modelData.name
          textFormat: Text.PlainText
          color: Color.popupText
          font.family: Style.fontFamily
          font.pixelSize: Style.fontSize - 1
          elide: Text.ElideRight
        }
        Text {
          id: spent

          anchors.right: parent.right
          text: page.duration(parent.modelData.minutes)
          color: Color.popupMuted
          font.family: Style.fontFamily
          font.pixelSize: Style.fontSize - 1
        }
      }
    }
    Quiet {
      visible: !!page.info && page.screen.since === ""
      text: "Counting from now: a minute counts while the screen is unlocked and in use."
    }
  }

  // --- what is playing ------------------------------------------------------------------
  Card {
    id: playing

    readonly property var player: Media.active

    x: page.colX(1)
    y: page.rowY(1)
    width: page.columnWidth
    fixedHeight: page.rowHeight
    order: 6
    appear: page.active
    icon: "\u{f075a}"
    title: player ? (player.identity || "Music") : "Music"
    tone: Color.popupAccent

    Item {
      width: parent.width
      height: playing.inner
      visible: !!playing.player

      Rectangle {
        id: art

        width: Math.min(96, playing.inner - controls.height - 12)
        height: width
        radius: Style.radius
        color: Color.popupHover
        clip: true

        Image {
          anchors.fill: parent
          source: playing.player && playing.player.trackArtUrl ? playing.player.trackArtUrl : ""
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
        }
      }
      Column {
        anchors.left: art.right
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.verticalCenter: art.verticalCenter
        spacing: 2

        Text {
          width: parent.width
          text: playing.player ? (playing.player.trackTitle || playing.player.identity) : ""
          textFormat: Text.PlainText
          color: Color.popupText
          font.family: Style.fontFamily
          font.pixelSize: Style.fontSize + 1
          font.weight: Style.barLabelWeight
          wrapMode: Text.WordWrap
          maximumLineCount: 2
          elide: Text.ElideRight
        }
        Text {
          width: parent.width
          text: playing.player ? (playing.player.trackArtist || "") : ""
          textFormat: Text.PlainText
          color: Color.popupMuted
          font.family: Style.fontFamily
          font.pixelSize: Style.fontSize - 1
          elide: Text.ElideRight
        }
      }
      Row {
        id: controls

        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 26

        Repeater {
          model: [
            { glyph: "\u{f04ae}", act: "previous" },
            { glyph: playing.player && playing.player.isPlaying ? "\u{f03e4}" : "\u{f040a}", act: "toggle" },
            { glyph: "\u{f04ad}", act: "next" }
          ]

          delegate: Text {
            required property var modelData

            text: modelData.glyph
            color: press.containsMouse ? Color.popupAccent : Color.popupText
            font.family: Style.fontFamily
            font.pixelSize: modelData.act === "toggle" ? 34 : 24
            anchors.verticalCenter: parent.verticalCenter

            MouseArea {
              id: press

              anchors.fill: parent
              anchors.margins: -6
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (!playing.player)
                  return;
                if (parent.modelData.act === "previous")
                  playing.player.previous();
                else if (parent.modelData.act === "next")
                  playing.player.next();
                else
                  playing.player.togglePlaying();
              }
            }
          }
        }
      }
    }
    Item {
      width: parent.width
      height: playing.inner
      visible: !playing.player

      Column {
        anchors.centerIn: parent
        spacing: 8

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "\u{f075b}"
          color: Color.popupMuted
          font.family: Style.fontFamily
          font.pixelSize: 34
        }
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "Nothing is playing"
          color: Color.popupMuted
          font.family: Style.fontFamily
          font.pixelSize: Style.fontSize
        }
      }
    }
  }

  // --- headlines: two wide, two tall ----------------------------------------------------
  Card {
    id: headlines

    // The newest from every feed, one list. Two from any one site at most in a row, so a
    // site that posts often does not fill the tile.
    readonly property var items: {
      var all = [];
      var feeds = page.news && page.news.feeds ? page.news.feeds : [];
      for (var f = 0; f < feeds.length; f++)
        for (var i = 0; i < feeds[f].items.length && i < 6; i++)
          all.push({
            site: feeds[f].name,
            title: feeds[f].items[i].title,
            link: feeds[f].items[i].link,
            at: feeds[f].items[i].at || 0
          });
      all.sort(function (a, b) {
        return b.at - a.at;
      });
      return all.slice(0, 30);
    }

    x: page.colX(2)
    y: page.rowY(1)
    width: page.wide(2)
    fixedHeight: page.tall(2)
    order: 7
    appear: page.active
    icon: "\u{f0395}"
    title: "Headlines"
    figure: page.news && page.news.connected === false ? "sample" : ""
    tone: Color.popupAccent

    Repeater {
      model: headlines.items

      delegate: Rectangle {
        id: line

        required property var modelData

        width: parent.width
        height: Style.fontSize + 16
        radius: Style.radius
        color: hover.containsMouse ? Color.popupHover : "transparent"

        Rectangle {
          id: badge

          anchors.left: parent.left
          anchors.leftMargin: 4
          anchors.verticalCenter: parent.verticalCenter
          width: 92
          height: Style.fontSize + 6
          radius: height / 2
          color: Qt.rgba(Color.popupAccent.r, Color.popupAccent.g, Color.popupAccent.b, 0.16)

          Text {
            anchors.centerIn: parent
            width: parent.width - 10
            horizontalAlignment: Text.AlignHCenter
            text: line.modelData.site
            textFormat: Text.PlainText
            color: Color.popupAccent
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSize - 3
            elide: Text.ElideRight
          }
        }
        Text {
          anchors.left: badge.right
          anchors.leftMargin: 10
          anchors.right: age.left
          anchors.rightMargin: 10
          anchors.verticalCenter: parent.verticalCenter
          text: line.modelData.title
          textFormat: Text.PlainText
          color: Color.popupText
          font.family: Style.fontFamily
          font.pixelSize: Style.fontSize - 1
          elide: Text.ElideRight
        }
        Text {
          id: age

          anchors.right: parent.right
          anchors.rightMargin: 6
          anchors.verticalCenter: parent.verticalCenter
          text: line.modelData.at > 0 ? page.ago(line.modelData.at) : ""
          color: Color.popupMuted
          font.family: Style.fontFamily
          font.pixelSize: Style.fontSize - 2
        }
        MouseArea {
          id: hover

          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: Qt.openUrlExternally(line.modelData.link)
        }
      }
    }
    Quiet {
      visible: headlines.items.length === 0
      text: "The headlines are being fetched."
    }
  }

  // --- this machine ---------------------------------------------------------------------
  Card {
    x: page.colX(0)
    y: page.rowY(2)
    width: page.columnWidth
    fixedHeight: page.rowHeight
    order: 8
    appear: page.active
    icon: "\u{f0565}"
    title: "This machine"
    figure: page.info && page.info.security.bad > 0 ? String(page.info.security.bad) : ""
    tone: page.info && page.info.security.bad > 0 ? Color.popupUrgent : Color.popupAccent

    PanelRow {
      width: parent.width
      icon: "\u{f06b0}"
      label: !page.info ? "Updates" : (page.info.updates.count === 0 ? "Up to date" : page.info.updates.count + (page.info.updates.count === 1 ? " update" : " updates"))
      active: !!page.info && page.info.updates.count > 0
      onClicked: page.run(["desktop-shell", "shell", "togglePanel", "updates"])
    }
    PanelRow {
      width: parent.width
      icon: "\u{f0e1e}"
      label: !page.info ? "Security" : (page.info.security.findings.length === 0 ? "Nothing to act on" : page.info.security.findings[0].title)
      active: !!page.info && page.info.security.bad > 0
      accentColor: Color.popupUrgent
      onClicked: page.run(["desktop-shell", "shell", "togglePanel", "security"])
    }
    PanelRow {
      width: parent.width
      icon: "\u{f0167}"
      label: page.info && page.info.backup.detail !== "" ? page.info.backup.detail.split("\n")[0] : "Backup"
      active: !!page.info && (page.info.backup.state === "stale" || page.info.backup.state === "never")
      accentColor: Color.popupUrgent
      onClicked: page.run(["desktop-shell", "shell", "togglePanel", "backup"])
    }
    PanelRow {
      width: parent.width
      visible: !!page.info && page.info.system.restart_marks.length > 0
      icon: "\u{f0709}"
      label: "A restart is pending"
      active: true
    }
  }

  // --- notifications --------------------------------------------------------------------
  Card {
    x: page.colX(1)
    y: page.rowY(2)
    width: page.columnWidth
    fixedHeight: page.rowHeight
    order: 9
    appear: page.active
    icon: "\u{f009a}"
    title: "Notifications"
    figure: Inbox.count > 0 ? String(Inbox.count) : ""
    tone: Color.popupAccent

    Repeater {
      model: page.info ? page.info.notifications.latest : []

      delegate: PanelRow {
        required property var modelData

        width: parent.width
        icon: "\u{f0f6a}"
        // One row a conversation: its title, who it is from and how many are waiting.
        label: modelData.summary
        sublabel: modelData.app + (modelData.count > 1 ? "  ·  " + modelData.count + " messages" : "")
        onClicked: page.run(["desktop-shell", "shell", "togglePanel", "notifications"])
      }
    }
    Quiet {
      visible: Inbox.count === 0
      text: "Nothing is waiting to be read."
    }
  }

  // --- the note -------------------------------------------------------------------------
  Card {
    id: notes

    x: page.colX(4)
    y: page.rowY(2)
    width: page.columnWidth
    fixedHeight: page.rowHeight
    order: 10
    appear: page.active
    icon: "\u{f03eb}"
    title: "Notes"
    tone: Color.popupAccent

    Rectangle {
      width: parent.width
      height: notes.inner
      radius: Style.radius
      color: note.activeFocus ? Color.popupHover : "transparent"
      border.width: 1
      border.color: note.activeFocus ? Color.popupAccent : "transparent"

      TextEdit {
        id: note

        anchors.fill: parent
        anchors.margins: 6
        color: Color.popupText
        selectionColor: Color.popupAccent
        selectedTextColor: Color.popupBackground
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSize
        wrapMode: TextEdit.Wrap
        textFormat: TextEdit.PlainText
        clip: true

        // Saved a moment after typing stops, not on every key.
        onTextChanged: if (activeFocus)
          saving.restart()
        Keys.onEscapePressed: {
          focus = false;
          page.typingDone();
        }
        onActiveFocusChanged: if (!activeFocus && saving.running) {
          saving.stop();
          page.run(["desktop-todo", "notes", text]);
        }

        Text {
          visible: note.text === "" && !note.activeFocus
          text: "Click to write a note."
          color: Color.popupMuted
          font: note.font
        }
      }
      Timer {
        id: saving

        interval: 800
        onTriggered: page.run(["desktop-todo", "notes", note.text])
      }
    }
  }

  // --- the dock -------------------------------------------------------------------------
  Rectangle {
    id: dock

    // Desktop entries by id, one a line, in ~/.config/desktop/dashboard/dock -- or these.
    readonly property var fallback: ["brave-browser", "com.mitchellh.ghostty", "org.gnome.Nautilus", "obsidian", "org.keepassxc.KeePassXC", "Claude", "org.gnome.Calculator"]
    property var wanted: fallback
    readonly property var apps: {
      var all = DesktopEntries.applications ? DesktopEntries.applications.values : [];
      var byId = {};
      for (var a = 0; a < all.length; a++)
        byId[all[a].id] = all[a];
      var out = [];
      for (var i = 0; i < wanted.length; i++)
        if (byId[wanted[i]])
          out.push(byId[wanted[i]]);
      return out;
    }

    x: 0
    y: page.rowY(3)
    width: page.width
    height: page.dockHeight
    radius: Style.radius
    color: Color.popupBackground
    border.width: 1
    border.color: Color.popupBorder
    opacity: page.active ? 1 : 0

    Behavior on opacity {
      NumberAnimation {
        duration: Style.motionEnter
      }
    }

    Row {
      anchors.fill: parent
      anchors.margins: 10
      spacing: 10

      Repeater {
        model: dock.apps

        delegate: Rectangle {
          id: app

          required property var modelData

          width: (parent.width - parent.spacing * (dock.apps.length - 1)) / Math.max(1, dock.apps.length)
          height: parent.height
          radius: Style.radius
          color: launch.containsMouse ? Color.popupHover : Qt.rgba(Color.popupText.r, Color.popupText.g, Color.popupText.b, 0.04)

          Behavior on color {
            ColorAnimation {
              duration: Style.motionQuick
            }
          }

          Column {
            anchors.centerIn: parent
            spacing: 4

            Image {
              anchors.horizontalCenter: parent.horizontalCenter
              width: 36
              height: 36
              sourceSize.width: 72
              sourceSize.height: 72
              source: app.modelData.icon ? Quickshell.iconPath(app.modelData.icon, true) : ""
              asynchronous: true
            }
            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              width: app.width - 12
              horizontalAlignment: Text.AlignHCenter
              text: app.modelData.name
              textFormat: Text.PlainText
              color: Color.popupText
              font.family: Style.fontFamily
              font.pixelSize: Style.fontSize - 2
              elide: Text.ElideRight
            }
          }
          MouseArea {
            id: launch

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            // As the launcher does: uwsm gives the app a systemd unit of its own.
            onClicked: page.run(app.modelData.runInTerminal ? ["uwsm", "app", "--", "ghostty", "-e"].concat(app.modelData.command) : ["uwsm", "app", "--"].concat(app.modelData.command))
          }
        }
      }
    }
  }

  // --- the files behind the to-do, the note and the dock ---------------------------------
  QtObject {
    id: todoFile

    property var items: []
  }
  FileView {
    path: Quickshell.env("HOME") + "/.local/state/desktop/todo.json"
    watchChanges: true
    printErrors: false
    onLoaded: {
      try {
        todoFile.items = JSON.parse(text()) || [];
      } catch (e) {
        todoFile.items = [];
      }
    }
    onFileChanged: reload()
    onLoadFailed: todoFile.items = []
  }
  FileView {
    path: Quickshell.env("HOME") + "/.local/state/desktop/notes.md"
    watchChanges: true
    printErrors: false
    // Not while it is being typed in: the save coming back would move the cursor.
    onLoaded: if (!note.activeFocus)
      note.text = text()
    onFileChanged: reload()
  }
  FileView {
    path: Quickshell.env("HOME") + "/.config/desktop/dashboard/dock"
    watchChanges: true
    printErrors: false
    onLoaded: {
      var ids = text().split("\n").map(function (l) {
        return l.replace(/#.*/, "").trim();
      }).filter(function (l) {
        return l !== "";
      });
      dock.wanted = ids.length > 0 ? ids : dock.fallback;
    }
    onFileChanged: reload()
    onLoadFailed: dock.wanted = dock.fallback
  }
}
