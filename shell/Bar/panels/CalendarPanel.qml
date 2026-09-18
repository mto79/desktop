import QtQuick
import qs.Commons
import qs.Ui
import "../../Commons/holidays.js" as Holidays

// Calendar panel: a month grid with ISO week numbers, hanging under the clock.
//
// Weeks start on the locale's first day and the week-number column is always shown --
// the bar's own alt format used to spell out `W ww`, and that habit is worth keeping
// for anyone whose meetings are booked by week number rather than by date.
//
// Laid out like the battery panel: today big at the top with the time, then the month,
// with Dutch public holidays marked -- computed in holidays.js, since there is no
// calendar on this machine to read them from -- and the next few listed with how far
// off they are. UTC sits in the grid for reading server logs against.
Popup {
  id: root

  readonly property string panelId: "calendar"

  // Refreshed by the timer below so the "today" ring survives a midnight rollover
  // while the panel happens to be open.
  property date today: new Date()
  property date selected: new Date()

  // The month on display. Plain properties, assigned by reset() and the arrows, rather
  // than bindings on `today`: a binding would snap the view back to this month the
  // moment the clock ticked over midnight.
  property int viewYear: 0
  property int viewMonth: 0

  readonly property var locale: Qt.locale()

  // Panels have no config entry of their own, so options come from the widget the
  // panel hangs under -- {"id": "clock", "firstDay": "monday"}. PopupHost hands us
  // that widget whether the panel was opened by click or over IPC.
  readonly property var widgetConfig: (anchorItem && anchorItem.widgetConfig) ? anchorItem.widgetConfig : ({})

  // Locale by default. Worth setting to monday next to ISO week numbers, which always
  // start there -- a Sunday-first grid puts week 37 beside a day that is still in 36.
  readonly property var dayNames: ({
      sunday: 0,
      monday: 1,
      tuesday: 2,
      wednesday: 3,
      thursday: 4,
      friday: 5,
      saturday: 6
    })

  readonly property int firstDayOfWeek: {
    var configured = widgetConfig.firstDay;
    if (configured === undefined || configured === "locale")
      return locale.firstDayOfWeek;
    if (typeof configured === "number")
      return Math.max(0, Math.min(6, configured));
    var named = dayNames[String(configured).toLowerCase()];
    return named !== undefined ? named : locale.firstDayOfWeek;
  }

  // Six rows always, so the panel does not change height between a 4-row February and
  // a 6-row month that starts on a Sunday.
  readonly property int weekCount: 6

  readonly property int weekColumnWidth: 34
  readonly property real cellWidth: (column.width - weekColumnWidth) / 7
  readonly property int cellHeight: 28

  function sameDay(a, b) {
    return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
  }

  // The grid starts on the first-day-of-week boundary at or before the 1st, so the
  // leading cells spill back into the previous month.
  readonly property date gridStart: {
    var first = new Date(viewYear, viewMonth, 1);
    var offset = (first.getDay() - firstDayOfWeek + 7) % 7;
    return new Date(viewYear, viewMonth, 1 - offset);
  }

  function dayAt(index) {
    var d = new Date(gridStart);
    d.setDate(d.getDate() + index);
    return d;
  }

  function shiftMonth(delta) {
    var d = new Date(viewYear, viewMonth + delta, 1);
    viewYear = d.getFullYear();
    viewMonth = d.getMonth();
  }

  function reset() {
    today = new Date();
    selected = today;
    viewYear = today.getFullYear();
    viewMonth = today.getMonth();
  }

  Component.onCompleted: reset()

  // Every open starts on the current month: a panel reopened next week should not
  // still be sitting on whatever month was last paged to.
  onVisibleChanged: if (visible)
    reset()

  // Every second while open: the time at the top is the one thing here that moves.
  Timer {
    interval: 1000
    repeat: true
    running: root.visible
    onTriggered: root.today = new Date()
  }

  // Holiday names by day for the years anything on screen can show: the month in view
  // spills into its neighbours, and today may be in neither. Keys carry the year, so one
  // map holds them all. Computed as a binding rather than filled in on demand -- writing a
  // property from inside the bindings that read it is a binding loop.
  readonly property var holidayMap: {
    var years = [viewYear - 1, viewYear, viewYear + 1, today.getFullYear(), selected.getFullYear()];
    var map = {};
    for (var i = 0; i < years.length; i++)
      Object.assign(map, Holidays.lookup(years[i]));
    return map;
  }

  function holiday(date) {
    return holidayMap[Holidays.key(date)] || "";
  }

  // Midnight to midnight: `selected` carries the time it was picked at, and 13:47 today
  // rounded against midnight is "in 1 day".
  function daysUntil(date) {
    var start = new Date(today.getFullYear(), today.getMonth(), today.getDate());
    var end = new Date(date.getFullYear(), date.getMonth(), date.getDate());
    return Math.round((end - start) / 86400000);
  }

  function dayOfYear(date) {
    return Math.round((new Date(date.getFullYear(), date.getMonth(), date.getDate()) - new Date(date.getFullYear(), 0, 1)) / 86400000) + 1;
  }

  readonly property int daysInYear: new Date(today.getFullYear(), 1, 29).getDate() === 29 ? 366 : 365
  readonly property var upcoming: Holidays.upcoming(today, 3)

  contentWidth: Style.popupWidth
  contentHeight: column.implicitHeight + Style.popupPadding * 2

  Column {
    id: column

    width: parent.width
    spacing: 2

    PanelHero {
      icon: "\u{f00ed}"
      title: Qt.formatDate(root.today, "dddd d MMMM")
      status: {
        var parts = ["week " + Dates.isoWeek(root.today)];
        var name = root.holiday(root.today);
        if (name !== "")
          parts.unshift(name);
        return parts.join("  ·  ");
      }
      statusColor: root.holiday(root.today) !== "" ? Color.popupAccent : Color.popupMuted
      value: Qt.formatTime(root.today, "HH:mm")
    }

    Grid {
      width: parent.width
      columns: 2
      topPadding: 2
      bottomPadding: 6

      PanelStat {
        label: "UTC"
        value: root.today.toISOString().substring(11, 16)
      }
      PanelStat {
        label: "Day"
        value: root.dayOfYear(root.today) + " of " + root.daysInYear
      }
    }

    // Month header: arrows page a month at a time, the title resets to today.
    Item {
      width: parent.width
      height: 30

      Text {
        id: prev

        anchors.left: parent.left
        anchors.leftMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        text: "\uf053"
        color: prevMouse.containsMouse ? Color.popupAccent : Color.popupMuted
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSize

        MouseArea {
          id: prevMouse

          anchors.fill: parent
          anchors.margins: -8
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.shiftMonth(-1)
        }
      }

      Text {
        id: title

        anchors.centerIn: parent
        text: root.locale.standaloneMonthName(root.viewMonth, Locale.LongFormat) + " " + root.viewYear
        color: titleMouse.containsMouse ? Color.popupAccent : Color.popupText
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSize
        font.bold: true

        MouseArea {
          id: titleMouse

          anchors.fill: parent
          anchors.margins: -6
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.reset()
        }
      }

      Text {
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        text: "\uf054"
        color: nextMouse.containsMouse ? Color.popupAccent : Color.popupMuted
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSize

        MouseArea {
          id: nextMouse

          anchors.fill: parent
          anchors.margins: -8
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.shiftMonth(1)
        }
      }
    }

    // Weekday initials, in the same column geometry as the grid below.
    Row {
      width: parent.width
      height: 20

      Item {
        width: root.weekColumnWidth
        height: parent.height
      }

      Repeater {
        model: 7

        delegate: Text {
          required property int index

          width: root.cellWidth
          height: parent.height
          // Locale.dayName takes 0 = Sunday, and 7 wraps back onto it.
          text: root.locale.dayName((root.firstDayOfWeek + index) % 7, Locale.ShortFormat).substring(0, 2)
          color: Color.popupMuted
          font.family: Style.fontFamily
          font.pixelSize: Style.fontSize - 2
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
        }
      }
    }

    Repeater {
      model: root.weekCount

      delegate: Row {
        id: week

        required property int index

        readonly property date firstDay: root.dayAt(index * 7)

        width: parent.width
        height: root.cellHeight

        Text {
          width: root.weekColumnWidth
          height: parent.height
          text: Dates.isoWeek(week.firstDay)
          color: Color.popupMuted
          font.family: Style.fontFamily
          font.pixelSize: Style.fontSize - 2
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
        }

        Repeater {
          model: 7

          delegate: Rectangle {
            id: cell

            required property int index

            readonly property date day: root.dayAt(week.index * 7 + cell.index)
            readonly property bool inMonth: day.getMonth() === root.viewMonth
            readonly property bool isToday: root.sameDay(day, root.today)
            readonly property bool isSelected: root.sameDay(day, root.selected)

            width: root.cellWidth
            height: parent.height
            radius: Style.radius
            color: isSelected ? Color.popupSelected : (cellMouse.containsMouse ? Color.popupHover : "transparent")
            // Today is a ring rather than a fill, so it stays visible underneath the
            // selection highlight when the two land on the same day.
            border.width: isToday ? 1 : 0
            border.color: Color.popupAccent

            readonly property string holidayName: root.holiday(cell.day)

            // A holiday is a dot under the number: the number itself stays legible, and
            // today's ring and the selection still read over it.
            Rectangle {
              visible: cell.holidayName !== ""
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.bottom: parent.bottom
              anchors.bottomMargin: 3
              width: 4
              height: 4
              radius: 2
              color: Color.popupAccent
              opacity: cell.inMonth ? 1.0 : 0.35
            }

            Text {
              anchors.fill: parent
              text: cell.day.getDate()
              color: cell.isToday || cell.holidayName !== "" ? Color.popupAccent : Color.popupText
              opacity: cell.inMonth ? 1.0 : 0.35
              font.family: Style.fontFamily
              font.pixelSize: Style.fontSize
              font.bold: cell.isToday
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
            }

            MouseArea {
              id: cellMouse

              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              // Picking a day in the spill-over cells follows the month it belongs to,
              // which is what every other calendar does and saves an arrow click.
              onClicked: {
                root.selected = cell.day;
                if (!cell.inMonth) {
                  root.viewYear = cell.day.getFullYear();
                  root.viewMonth = cell.day.getMonth();
                }
              }
            }
          }
        }
      }
    }

    PanelSection {
      title: "Selected"
      value: "week " + Dates.isoWeek(root.selected)
      rule: true
    }

    PanelRow {
      icon: "\u{f00f0}"
      label: Qt.formatDate(root.selected, "dddd d MMMM yyyy")
      sublabel: {
        var parts = [];
        var name = root.holiday(root.selected);
        if (name !== "")
          parts.push(name);
        var days = root.daysUntil(root.selected);
        if (days === 0)
          parts.push("today");
        else
          parts.push(days > 0 ? "in " + days + (days === 1 ? " day" : " days") : Math.abs(days) + (days === -1 ? " day ago" : " days ago"));
        return parts.join("  ·  ");
      }
      enabled: false
    }

    // --- The next days off, or near enough ------------------------------------------
    PanelSection {
      title: "Holidays"
      value: "the Netherlands"
      rule: true
    }

    Repeater {
      model: root.upcoming

      delegate: PanelRow {
        id: holidayRow

        required property var modelData

        readonly property int days: root.daysUntil(modelData.date)

        icon: "\u{f0153}"
        label: modelData.name
        sublabel: Qt.formatDate(modelData.date, "dddd d MMMM")
        active: days === 0
        // Clicking shows it in the grid.
        onClicked: {
          root.selected = modelData.date;
          root.viewYear = modelData.date.getFullYear();
          root.viewMonth = modelData.date.getMonth();
        }

        Text {
          text: holidayRow.days === 0 ? "today" : "in " + holidayRow.days + (holidayRow.days === 1 ? " day" : " days")
          color: holidayRow.days <= 7 ? Color.popupAccent : Color.popupMuted
          font.family: Style.fontFamily
          font.pixelSize: Style.fontSize - 2
        }
      }
    }
  }
}
