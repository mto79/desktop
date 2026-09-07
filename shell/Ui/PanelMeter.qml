import QtQuick
import qs.Commons

// A read-only horizontal bar for a panel row.
//
// PanelSlider is the interactive one -- it drags, and emits a value. This is for the
// figures you can only look at, where a proportion is easier to read than a number.
//
// Two fills rather than one: `value` is the part that is genuinely spoken for, and
// `secondary` is drawn immediately after it in a muted colour. Memory needs that
// distinction badly, because cache occupies pages while not really costing you
// anything -- one bar showing "94% full" would be true and completely misleading.
Item {
  id: root

  property real value: 0
  property real secondary: 0
  property color fillColor: Color.popupAccent
  property color secondaryColor: Qt.rgba(Color.popupAccent.r, Color.popupAccent.g, Color.popupAccent.b, 0.35)

  readonly property real clampedValue: Math.max(0, Math.min(1, value))
  // Clamped against what is left, so a rounding error cannot push the second fill past
  // the end of the track.
  readonly property real clampedSecondary: Math.max(0, Math.min(1 - clampedValue, secondary))

  implicitHeight: 6

  Rectangle {
    id: track

    anchors.fill: parent
    radius: Style.radius > 0 ? Style.radius : height / 2
    color: Color.popupHover
  }

  Rectangle {
    id: used

    anchors.left: track.left
    anchors.top: track.top
    anchors.bottom: track.bottom
    width: track.width * root.clampedValue
    radius: track.radius
    color: root.fillColor
  }

  Rectangle {
    anchors.left: used.right
    anchors.top: track.top
    anchors.bottom: track.bottom
    width: track.width * root.clampedSecondary
    radius: track.radius
    color: root.secondaryColor
  }
}
