import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui
import "../Commons/holidays.js" as Holidays

// Start: what needs you. Every one of these has a panel of its own; this is all of them
// already open. From desktop-dash start, which is desktop-brief.
GridLayout {
  id: page

  property var info: null
  property bool active: false
  property date now: new Date()

  columns: width > 1500 ? 3 : (width > 900 ? 2 : 1)
  columnSpacing: Style.overviewSpacing
  rowSpacing: Style.overviewSpacing

  function stateText(session) {
    var what = {
      "waiting": "waiting for you",
      "working": "working",
      "done": "finished",
      "ready": "open"
    }[session.state] || session.state;
    return session["for"] ? what + "  ·  " + session["for"] : what;
  }

  function stateGlyph(state) {
    return state === "waiting" ? "\u{f0026}" : state === "done" ? "\u{f012c}" : state === "working" ? "\u{f06a9}" : "\u{f0765}";
  }

  function jump(target, socket) {
    if (target)
      Quickshell.execDetached(["desktop-menu-agents", "--jump", target, socket || ""]);
  }

  function daysUntil(date) {
    var start = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    var days = Math.round((date.getTime() - start.getTime()) / 86400000);
    return days === 0 ? "today" : days === 1 ? "tomorrow" : "in " + days + " days";
  }

    // --- agents
    Card {
      order: 0
      appear: page.active
      icon: "\u{f06a9}"
      title: "Agents"
      figure: page.info ? String(page.info.agents.sessions.length) : ""
      tone: page.info && page.info.agents.waiting > 0 ? Color.popupUrgent : Color.popupAccent

      Repeater {
        model: page.info ? page.info.agents.sessions.slice(0, 7) : []

        delegate: PanelRow {
          required property var modelData

          width: parent.width
          icon: page.stateGlyph(modelData.state)
          label: modelData.project
          sublabel: page.stateText(modelData)
          active: modelData.state === "waiting"
          accentColor: modelData.state === "waiting" ? Color.popupUrgent : Color.popupAccent
          enabled: !!modelData.target
          onClicked: page.jump(modelData.target, modelData.socket)
        }
      }
      Quiet {
        visible: !!page.info && page.info.agents.sessions.length === 0
        text: "No agent is running."
      }
    }

    // --- tasks
    Card {
      order: 1
      appear: page.active
      icon: "\u{f062c}"
      title: "Tasks"
      figure: page.info ? String(page.info.tasks.length) : ""
      tone: Color.popupAccent

      Repeater {
        model: page.info ? page.info.tasks.slice(0, 7) : []

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
        visible: !!page.info && page.info.tasks.length === 0
        text: "No task is open. prefix + T in tmux starts one."
      }
    }

    // --- the machine
    Card {
      order: 2
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

    // --- Claude's limits
    Card {
      order: 3
      appear: page.active
      icon: "\u{f1719}"
      title: "Claude"
      figure: page.info && page.info.limits.length > 0 ? Math.max.apply(null, page.info.limits.map(function (l) {
        return l.percent;
      })) + "%" : ""
      tone: Color.popupAccent

      Repeater {
        model: page.info ? page.info.limits : []

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
        visible: !!page.info && page.info.limits.length === 0
        text: "No usage report -- offline, or the login has expired."
      }
    }

    // --- notifications
    Card {
      order: 4
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
      order: 5
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
