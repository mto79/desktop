import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui
import "../Commons/holidays.js" as Holidays

// Start: what needs you. Every one of these has a panel of its own; this is all of them
// already open. From desktop-dash start, which is desktop-brief. The agents, their tasks
// and Claude's limits are not here: they have a heading of the AI tab to themselves, and
// the line under the clock still says when one of them is waiting.
GridLayout {
  id: page

  property var info: null
  property bool active: false
  property date now: new Date()

  columns: width > 1500 ? 3 : (width > 900 ? 2 : 1)
  columnSpacing: Style.overviewSpacing
  rowSpacing: Style.overviewSpacing

  function daysUntil(date) {
    var start = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    var days = Math.round((date.getTime() - start.getTime()) / 86400000);
    return days === 0 ? "today" : days === 1 ? "tomorrow" : "in " + days + " days";
  }

    // --- the machine
    Card {
      order: 0
      appear: page.active
      icon: "\u{f0565}"
      title: "This machine"
      figure: page.info && page.info.security.bad > 0 ? String(page.info.security.bad) : ""
      tone: page.info && page.info.security.bad > 0 ? Color.popupUrgent : Color.popupAccent

      PanelRow {
        width: parent.width
        icon: "\u{f06b0}"
        label: !page.info ? "Updates" : (page.info.updates.count === 0 ? "Up to date" : page.info.updates.count + (page.info.updates.count === 1 ? " update" : " updates"))
        sublabel: page.info ? page.info.updates.sources.map(function (s) {
          return s.count + " " + s.label;
        }).join("  ·  ") : ""
        active: !!page.info && page.info.updates.count > 0
        onClicked: Quickshell.execDetached(["desktop-shell", "shell", "togglePanel", "updates"])
      }
      PanelRow {
        width: parent.width
        icon: "\u{f0e1e}"
        label: !page.info ? "Security" : (page.info.security.findings.length === 0 ? "Nothing to act on" : page.info.security.findings.length + (page.info.security.findings.length === 1 ? " finding" : " findings"))
        sublabel: page.info && page.info.security.findings.length > 0 ? page.info.security.findings[0].title : ""
        active: !!page.info && page.info.security.bad > 0
        accentColor: Color.popupUrgent
        onClicked: Quickshell.execDetached(["desktop-shell", "shell", "togglePanel", "security"])
      }
      PanelRow {
        width: parent.width
        icon: "\u{f0167}"
        label: "Backup"
        sublabel: page.info ? (page.info.backup.detail !== "" ? page.info.backup.detail.split("\n")[0] : "no report") : ""
        active: !!page.info && (page.info.backup.state === "stale" || page.info.backup.state === "never")
        accentColor: Color.popupUrgent
        onClicked: Quickshell.execDetached(["desktop-shell", "shell", "togglePanel", "backup"])
      }
      PanelRow {
        width: parent.width
        visible: !!page.info && page.info.system.restart_marks.length > 0
        icon: "\u{f0709}"
        label: "A restart is pending"
        sublabel: "something was updated that only takes effect after one"
        active: true
      }
      PanelRow {
        width: parent.width
        icon: "\u{f02ca}"
        label: page.info ? "Disk " + page.info.system.disk_used + "% used" : "Disk"
        sublabel: page.info ? "up " + page.info.system.uptime + "  ·  " + page.info.system.kernel : ""
        enabled: false
      }
    }

    // --- notifications
    Card {
      order: 1
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
          label: modelData.summary
          sublabel: modelData.app
          onClicked: Quickshell.execDetached(["desktop-shell", "shell", "togglePanel", "notifications"])
        }
      }
      Quiet {
        visible: Inbox.count === 0
        text: "Nothing is waiting to be read."
      }
    }

    // --- the days ahead
    Card {
      order: 2
      appear: page.active
      icon: "\u{f00ed}"
      title: "Coming up"
      figure: "week " + Dates.isoWeek(page.now)
      tone: Color.popupAccent

      Repeater {
        model: Holidays.upcoming(page.now, 4)

        delegate: PanelRow {
          required property var modelData

          width: parent.width
          icon: "\u{f00f0}"
          label: modelData.name
          sublabel: Qt.formatDate(modelData.date, "dddd d MMMM") + "  ·  " + page.daysUntil(modelData.date)
          enabled: false
        }
      }
    }

}
