import QtQuick
import qs.Commons
import qs.Ui

// A deliberate gap between groups of widgets.
//
// Padding is uniform by nature, so tightening it moves everything closer to everything
// and the bar reads as one undifferentiated row of glyphs. What the eye actually wants
// is unequal spacing: connectivity together, sound together, system together, with air
// between the groups. That is what this is for -- it buys legibility rather than space,
// which is the right trade on a bar using a third of its monitor.
//
//   {"id": "spacer"}                 a gap of Style.barGroupSpacing
//   {"id": "spacer", "width": 16}    a wider one
//   {"id": "spacer", "rule": true}   a hairline instead of empty air
//
// Deliberately dumb about its neighbours: a widget that hides itself when idle (camera,
// voxtype, vpn) would otherwise need the spacer to know, and a gap that merges with the
// one next to it is a slightly wider gap, not a visible fault.
BarWidget {
  id: root

  readonly property int size: (widgetConfig && widgetConfig.width !== undefined) ? widgetConfig.width : Style.barGroupSpacing
  readonly property bool rule: !!(widgetConfig && widgetConfig.rule)

  implicitWidth: size

  Rectangle {
    anchors.centerIn: parent
    width: 1
    height: Math.round(parent.height * 0.4)
    visible: root.rule
    // Faint on purpose: a separator that competes with the widgets it separates has
    // made the bar busier, not clearer.
    color: Qt.rgba(Color.barMuted.r, Color.barMuted.g, Color.barMuted.b, 0.45)
  }
}
