import QtQuick
import qs.Commons

// Who is near, drawn as rings around this machine: the nearer a device, the nearer the
// middle. For the network that is how fast a device answers; for Bluetooth, how strong its
// signal is. A device has its own direction, worked out from its key, so it stays in the
// same place from one scan to the next and only moves in or out.
//
//   points   [{ key, label, near (0 = here, 1 = the outer ring), tone, ring? }]
//            "ring": true draws a device known to be there but not heard from: on the
//            outer ring, hollow
//   rings    [{ at (0..1), label }]: the circles, and what each stands for
Item {
  id: radar

  property var points: []
  property var rings: []
  property string centre: "this machine"
  property color tone: Color.popupAccent
  property string hovered: ""

  implicitHeight: 320
  // Names near the edge stop at it rather than run into what is beside the radar.
  clip: true

  readonly property real radius: Math.min(width, height) / 2 - 18
  readonly property real cx: width / 2
  readonly property real cy: height / 2

  // A direction for a key: the same key, the same angle, spread round the circle.
  function angle(key) {
    var h = 2166136261;
    for (var i = 0; i < key.length; i++) {
      h ^= key.charCodeAt(i);
      h = (h * 16777619) >>> 0;
    }
    return (h % 3600) / 3600 * Math.PI * 2;
  }

  Canvas {
    id: canvas

    anchors.fill: parent
    onPaint: {
      var ctx = getContext("2d");
      ctx.reset();
      ctx.lineWidth = 1;
      for (var i = 0; i < radar.rings.length; i++) {
        ctx.strokeStyle = Qt.rgba(Color.popupText.r, Color.popupText.g, Color.popupText.b, 0.14);
        ctx.beginPath();
        ctx.arc(radar.cx, radar.cy, Math.max(4, radar.rings[i].at * radar.radius), 0, Math.PI * 2);
        ctx.stroke();
      }
      // Two faint cross lines, so it reads as a radar and not as a target.
      ctx.strokeStyle = Qt.rgba(Color.popupText.r, Color.popupText.g, Color.popupText.b, 0.06);
      ctx.beginPath();
      ctx.moveTo(radar.cx - radar.radius, radar.cy);
      ctx.lineTo(radar.cx + radar.radius, radar.cy);
      ctx.moveTo(radar.cx, radar.cy - radar.radius);
      ctx.lineTo(radar.cx, radar.cy + radar.radius);
      ctx.stroke();
    }
  }
  onRingsChanged: canvas.requestPaint()
  onWidthChanged: canvas.requestPaint()
  onHeightChanged: canvas.requestPaint()

  Repeater {
    model: radar.rings

    delegate: Text {
      required property var modelData

      // Under the middle, inside each ring: a name beside a dot is drawn above them.
      x: radar.cx + 4
      y: radar.cy + modelData.at * radar.radius - height - 1
      text: modelData.label
      textFormat: Text.PlainText
      color: Color.popupMuted
      font.family: Style.fontFamily
      font.pixelSize: Style.fontSize - 3
    }
  }

  Rectangle {
    x: radar.cx - width / 2
    y: radar.cy - height / 2
    width: 14
    height: 14
    radius: 7
    color: radar.tone
  }
  // What the middle is, in the corner: under the dot it would sit on the nearest devices'
  // names, which is where the radar is busiest.
  Row {
    spacing: 6

    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      width: 8
      height: 8
      radius: 4
      color: radar.tone
    }
    Text {
      text: radar.centre
      textFormat: Text.PlainText
      color: Color.popupMuted
      font.family: Style.fontFamily
      font.pixelSize: Style.fontSize - 2
    }
  }

  Repeater {
    model: radar.points

    delegate: Item {
      id: point

      required property var modelData
      readonly property real a: radar.angle(modelData.key)
      readonly property real r: Math.max(0.16, Math.min(1, modelData.near)) * radar.radius
      readonly property bool lit: radar.hovered === modelData.key || dotArea.containsMouse

      x: radar.cx + Math.cos(a) * r - 6
      y: radar.cy + Math.sin(a) * r - 6
      width: 12
      height: 12

      Behavior on x {
        NumberAnimation {
          duration: Style.motionQuick
        }
      }
      Behavior on y {
        NumberAnimation {
          duration: Style.motionQuick
        }
      }

      Rectangle {
        anchors.fill: parent
        radius: 6
        color: point.modelData.ring ? "transparent" : point.modelData.tone
        border.width: point.modelData.ring || point.lit ? 2 : 0
        border.color: point.lit ? Color.popupText : point.modelData.tone
        scale: point.lit ? 1.4 : 1
      }

      Text {
        id: name

        // The name beside the dot, on the side away from the middle -- unless that side has
        // less room than the other, near the edge, where the name would be cut off.
        readonly property real wanted: Math.min(implicitWidth, 160)
        readonly property real roomRight: radar.width - point.x - 16
        readonly property real roomLeft: point.x - 4
        readonly property bool toRight: Math.cos(point.a) >= 0 ? (roomRight >= wanted || roomRight >= roomLeft) : !(roomLeft >= wanted || roomLeft >= roomRight)

        x: toRight ? 16 : -width - 4
        y: -2
        z: 1
        text: point.modelData.label
        textFormat: Text.PlainText
        color: point.lit ? Color.popupText : Color.popupMuted
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSize - 2
        visible: point.lit || radar.points.length <= 14
        elide: Text.ElideRight
        width: Math.max(0, Math.min(wanted, toRight ? roomRight : roomLeft))
      }

      MouseArea {
        id: dotArea

        anchors.fill: parent
        anchors.margins: -6
        hoverEnabled: true
        onContainsMouseChanged: radar.hovered = containsMouse ? point.modelData.key : ""
      }
    }
  }
}
