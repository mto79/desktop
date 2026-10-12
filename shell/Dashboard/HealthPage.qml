import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

// Health: the week's activity, and the body's own numbers. From desktop-dash health,
// which reads a file you keep -- nothing here logs in to Strava or Garmin.
ColumnLayout {
  id: page

  property var info: null
  property bool active: false

  spacing: Style.overviewSpacing

  readonly property real progress: info && info.week && info.week.goal_km > 0 ? Math.min(1, info.week.distance_km / info.week.goal_km) : 0

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
      Layout.columnSpan: 2
      icon: "\u{f070e}"
      title: "This week"
      figure: Math.round(page.progress * 100) + "% of the goal"
      tone: Color.good

      Row {
        spacing: Style.overviewSpacing * 1.5
        topPadding: 6
        bottomPadding: 10

        Figure {
          appear: page.active
          value: page.info && page.info.week ? page.info.week.distance_km : 0
          decimals: 1
          unit: "km"
          label: "distance"
          tone: Color.good
        }
        Figure {
          appear: page.active
          value: page.info && page.info.week ? page.info.week.hours : 0
          decimals: 1
          unit: "h"
          label: "moving"
        }
        Figure {
          appear: page.active
          value: page.info && page.info.week ? page.info.week.activities : 0
          label: "activities"
        }
      }
      // The goal, as a bar that fills to where the week has got to.
      Rectangle {
        width: parent.width
        height: 8
        radius: 4
        color: Color.popupBorder

        Rectangle {
          height: parent.height
          radius: parent.radius
          color: Color.good
          width: page.active ? parent.width * page.progress : 0

          Behavior on width {
            NumberAnimation {
              duration: 900
              easing.type: Easing.OutCubic
            }
          }
        }
      }
      Bars {
        width: parent.width
        appear: page.active
        values: page.info && page.info.days ? page.info.days : []
        field: "km"
        tone: Color.good
      }
    }

    Card {
      order: 1
      appear: page.active
      icon: "\u{f02d1}"
      title: "Body"
      tone: Color.popupUrgent

      Column {
        spacing: Style.sectionSpacing
        topPadding: 6

        Figure {
          appear: page.active
          value: page.info && page.info.body ? page.info.body.resting_hr : 0
          unit: "bpm"
          label: "resting heart rate"
          tone: Color.popupUrgent
        }
        Figure {
          appear: page.active
          value: page.info && page.info.body ? page.info.body.sleep_hours : 0
          decimals: 1
          unit: "h"
          label: "sleep"
          tone: Color.popupAccent
        }
        Figure {
          appear: page.active
          value: page.info && page.info.body ? page.info.body.steps : 0
          label: "steps"
        }
      }
    }

    Card {
      order: 2
      appear: page.active
      Layout.columnSpan: page.width > 1300 ? 3 : 2
      icon: "\u{f046d}"
      title: "Recently"
      tone: Color.popupAccent

      Repeater {
        model: page.info && page.info.recent ? page.info.recent : []

        delegate: PanelRow {
          required property var modelData

          width: parent.width
          icon: modelData.kind === "ride" ? "\u{f00a3}" : "\u{f070e}"
          label: modelData.name
          sublabel: modelData.km + " km  ·  " + modelData.minutes + " min"
          enabled: false
        }
      }
    }
  }
}
