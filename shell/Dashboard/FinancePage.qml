import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

// Finance: the month against its budget, and where the balance has been going. From
// desktop-dash finance, which reads a file you keep -- nothing here logs in to a bank.
ColumnLayout {
  id: page

  property var info: null
  property bool active: false

  spacing: Style.overviewSpacing

  readonly property string sign: info && info.currency ? info.currency : ""
  readonly property real used: info && info.month && info.month.budget > 0 ? info.month.spent / info.month.budget : 0

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
      icon: "\u{f0116}"
      title: "This month"
      figure: Math.round(page.used * 100) + "% of budget"
      tone: page.used > 1 ? Color.popupUrgent : (page.used > 0.85 ? Color.caution : Color.good)

      Row {
        spacing: Style.overviewSpacing * 1.5
        topPadding: 6
        bottomPadding: 10

        Figure {
          appear: page.active
          prefix: page.sign
          value: page.info && page.info.month ? page.info.month.spent : 0
          label: "spent"
          tone: page.used > 1 ? Color.popupUrgent : Color.popupText
        }
        Figure {
          appear: page.active
          prefix: page.sign
          value: page.info && page.info.month ? page.info.month.income : 0
          label: "in"
          tone: Color.good
        }
      }
      Rectangle {
        width: parent.width
        height: 8
        radius: 4
        color: Color.popupBorder

        Rectangle {
          height: parent.height
          radius: parent.radius
          color: page.used > 1 ? Color.popupUrgent : (page.used > 0.85 ? Color.caution : Color.good)
          width: page.active ? parent.width * Math.min(1, page.used) : 0

          Behavior on width {
            NumberAnimation {
              duration: 900
              easing.type: Easing.OutCubic
            }
          }
        }
      }
      Quiet {
        topPadding: 4
        text: page.info && page.info.month ? "budget " + page.sign + page.info.month.budget : ""
      }
    }

    Card {
      order: 1
      appear: page.active
      Layout.columnSpan: page.width > 1300 ? 2 : 1
      icon: "\u{f012a}"
      title: "Balance"
      figure: page.info && page.info.balance && page.info.balance.length > 0 ? page.sign + page.info.balance[page.info.balance.length - 1] : ""
      tone: Color.popupAccent

      Trend {
        width: parent.width
        appear: page.active
        values: page.info && page.info.balance ? page.info.balance : []
      }
    }

    Card {
      order: 2
      appear: page.active
      Layout.columnSpan: page.width > 1300 ? 2 : 1
      icon: "\u{f0bc8}"
      title: "Where it went"
      tone: Color.popupAccent

      Bars {
        width: parent.width
        implicitHeight: 150
        appear: page.active
        values: page.info && page.info.categories ? page.info.categories.map(function (c) {
          return {
            label: c.name,
            value: c.amount
          };
        }) : []
      }
    }

    Card {
      order: 3
      appear: page.active
      icon: "\u{f00ed}"
      title: "Coming up"
      tone: Color.caution

      Repeater {
        model: page.info && page.info.upcoming ? page.info.upcoming : []

        delegate: PanelRow {
          required property var modelData

          width: parent.width
          icon: "\u{f00f0}"
          label: modelData.name
          sublabel: page.sign + modelData.amount + "  ·  in " + modelData.in_days + " days"
          enabled: false
        }
      }
    }
  }
}
