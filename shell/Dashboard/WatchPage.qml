import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

// Watching: software worth keeping an eye on, and what has a newer version than the one
// installed here. From desktop-dash watch, which asks where each publishes its releases.
ColumnLayout {
  id: page

  property var info: null
  property bool active: false

  spacing: Style.overviewSpacing

  readonly property var behind: info ? info.items.filter(function (i) {
    return i.state === "behind";
  }) : []
  readonly property var rest: info ? info.items.filter(function (i) {
    return i.state !== "behind";
  }) : []

  Unconnected {
    visible: !!page.info && page.info.connected === false
    how: page.info && page.info.how ? page.info.how : []
  }

  GridLayout {
    Layout.fillWidth: true
    columns: page.width > 1300 ? 3 : 2
    columnSpacing: Style.overviewSpacing
    rowSpacing: Style.overviewSpacing

    Card {
      order: 0
      appear: page.active
      icon: "\u{f06b0}"
      title: "At a glance"
      tone: page.behind.length > 0 ? Color.caution : Color.good

      Row {
        spacing: Style.overviewSpacing * 1.5
        topPadding: 6
        bottomPadding: 6

        Figure {
          appear: page.active
          value: page.behind.length
          label: "newer out there"
          tone: page.behind.length > 0 ? Color.caution : Color.good
        }
        Figure {
          appear: page.active
          value: page.info ? page.info.total : 0
          label: "watched"
        }
      }
      Quiet {
        text: page.info && page.info.checked ? "Asked " + Qt.formatDateTime(new Date(page.info.checked * 1000), "ddd HH:mm") + "  ·  again every six hours" : ""
      }
    }

    Card {
      order: 1
      appear: page.active
      Layout.columnSpan: page.width > 1300 ? 2 : 1
      icon: "\u{f0552}"
      title: "A newer version is out"
      figure: page.behind.length > 0 ? String(page.behind.length) : ""
      tone: Color.caution

      Repeater {
        model: page.behind

        delegate: PanelRow {
          required property var modelData

          width: parent.width
          icon: "\u{f0552}"
          accentColor: Color.caution
          active: true
          label: modelData.name
          sublabel: modelData.installed + "  →  " + modelData.newest + "    " + modelData.source
          enabled: false
        }
      }
      Quiet {
        visible: !!page.info && page.behind.length === 0
        text: "Everything watched is at its newest version."
      }
    }

    Card {
      order: 2
      appear: page.active
      Layout.columnSpan: page.width > 1300 ? 3 : 2
      icon: "\u{f012c}"
      title: "Up to date"
      figure: String(page.rest.length)
      tone: Color.good

      GridLayout {
        width: parent.width
        columns: page.width > 1300 ? 3 : 2
        columnSpacing: Style.sectionSpacing
        rowSpacing: 0

        Repeater {
          model: page.rest

          delegate: PanelRow {
            required property var modelData

            Layout.fillWidth: true
            icon: modelData.state === "current" ? "\u{f012c}" : "\u{f02d6}"
            label: modelData.name
            sublabel: modelData.state === "current" ? modelData.installed : (modelData.state === "absent" ? "not installed  ·  newest " + modelData.newest : "could not be asked")
            enabled: false
          }
        }
      }
    }
  }
}
