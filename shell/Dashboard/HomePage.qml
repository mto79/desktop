import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

// Domotics: the house, from Home Assistant. From desktop-dash home; which things are shown,
// and what each is called, is home.conf's to say.
ColumnLayout {
  id: page

  property var info: null
  property bool active: false

  spacing: Style.overviewSpacing

  function of(kind) {
    return info ? info.rooms.filter(function (r) {
      return r.kind === kind;
    }) : [];
  }

  readonly property var climate: of("climate")
  readonly property var lights: of("light")
  readonly property var power: of("power")
  readonly property var others: info ? info.rooms.filter(function (r) {
    return ["climate", "light", "power"].indexOf(r.kind) === -1;
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
      Layout.columnSpan: page.width > 1300 ? 2 : 2
      icon: "\u{f050f}"
      title: "Climate"
      tone: Color.popupAccent

      Flow {
        width: parent.width
        spacing: Style.overviewSpacing * 1.5
        topPadding: 6
        bottomPadding: 6

        Repeater {
          model: page.climate

          delegate: Figure {
            required property var modelData

            appear: page.active
            value: Number(modelData.value) || 0
            decimals: 1
            unit: modelData.unit
            label: modelData.label
          }
        }
      }
      Quiet {
        visible: page.climate.length === 0
        text: "Nothing of the kind \"climate\" in home.conf."
      }
    }

    Card {
      order: 1
      appear: page.active
      icon: "\u{f0335}"
      title: "Lights"
      figure: page.lights.filter(function (l) {
        return l.value === "on";
      }).length + " on"
      tone: Color.caution

      Repeater {
        model: page.lights

        delegate: PanelRow {
          required property var modelData

          width: parent.width
          icon: modelData.value === "on" ? "\u{f06e8}" : "\u{f0336}"
          accentColor: Color.caution
          active: modelData.value === "on"
          label: modelData.label
          sublabel: modelData.value
          enabled: false
        }
      }
    }

    Card {
      order: 2
      appear: page.active
      icon: "\u{f140b}"
      title: "Energy"
      tone: Color.good

      Flow {
        width: parent.width
        spacing: Style.overviewSpacing * 1.5
        topPadding: 6
        bottomPadding: 6

        Repeater {
          model: page.power

          delegate: Figure {
            required property var modelData

            appear: page.active
            value: Number(modelData.value) || 0
            unit: modelData.unit
            label: modelData.label
            tone: Color.good
          }
        }
      }
    }

    Card {
      order: 3
      appear: page.active
      Layout.columnSpan: page.width > 1300 ? 2 : 1
      visible: page.others.length > 0
      icon: "\u{f02dc}"
      title: "Also"
      tone: Color.popupAccent

      Repeater {
        model: page.others

        delegate: PanelRow {
          required property var modelData

          width: parent.width
          icon: modelData.kind === "lock" ? "\u{f033e}" : "\u{f0a4c}"
          label: modelData.label
          sublabel: modelData.value + (modelData.unit ? " " + modelData.unit : "")
          enabled: false
        }
      }
    }
  }
}
