import QtQuick
import QtQuick.Shapes
import qs.Commons

// A ring that fills clockwise from the top: a share of something, read at a glance -- CPU,
// memory, a limit. The figure sits inside with a word under it, and an optional third line
// under that ("reset 18:49").
//
// Coloured by how full it is (Color.gauge) unless told a tone, so a ring at 90% says so
// before its number is read. It fills from empty when it appears and moves to each new
// value, the way Figure counts up.
Item {
  id: ring

  property real value: 0            // 0..1
  property string text: ""          // inside, large
  property string label: ""         // inside, small, under it
  property string detail: ""        // inside, smaller still
  property color tone: Color.gauge(value)
  property real thickness: Math.max(5, width / 14)
  property bool appear: true

  property real shown: 0

  implicitWidth: 110
  // Square: given a width, it is as tall as that.
  height: width

  onAppearChanged: shown = appear ? Math.max(0, Math.min(1, value)) : 0
  onValueChanged: if (appear)
    shown = Math.max(0, Math.min(1, value))
  Component.onCompleted: if (appear)
    shown = Math.max(0, Math.min(1, value))

  Behavior on shown {
    NumberAnimation {
      duration: 700
      easing.type: Easing.OutCubic
    }
  }

  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer

    // The track.
    ShapePath {
      fillColor: "transparent"
      strokeColor: Color.popupBorder
      strokeWidth: ring.thickness
      capStyle: ShapePath.RoundCap

      PathAngleArc {
        centerX: ring.width / 2
        centerY: ring.height / 2
        radiusX: (ring.width - ring.thickness) / 2
        radiusY: radiusX
        startAngle: 0
        sweepAngle: 360
      }
    }
    // The share.
    ShapePath {
      fillColor: "transparent"
      strokeColor: ring.shown > 0.001 ? ring.tone : "transparent"
      strokeWidth: ring.thickness
      capStyle: ShapePath.RoundCap

      PathAngleArc {
        centerX: ring.width / 2
        centerY: ring.height / 2
        radiusX: (ring.width - ring.thickness) / 2
        radiusY: radiusX
        startAngle: -90
        sweepAngle: 360 * ring.shown
      }
    }
  }

  Column {
    anchors.centerIn: parent
    width: ring.width - ring.thickness * 4
    spacing: 0

    Text {
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      text: ring.text
      color: Color.popupText
      font.family: Style.fontFamily
      font.pixelSize: Math.max(Style.fontSize, ring.width / 5)
      font.weight: Style.barLabelWeight
      fontSizeMode: Text.HorizontalFit
      minimumPixelSize: Style.fontSize - 2
    }
    Text {
      width: parent.width
      visible: ring.label !== ""
      horizontalAlignment: Text.AlignHCenter
      text: ring.label
      color: Color.popupMuted
      font.family: Style.fontFamily
      font.pixelSize: Style.fontSize - 2
      elide: Text.ElideRight
    }
    Text {
      width: parent.width
      visible: ring.detail !== ""
      horizontalAlignment: Text.AlignHCenter
      text: ring.detail
      color: Color.popupMuted
      font.family: Style.fontFamily
      font.pixelSize: Style.fontSize - 3
      elide: Text.ElideRight
    }
  }
}
