import QtQuick
import qs.Commons

// A volume slider. Drag, click-to-seek, and scroll.
//
// `value` is only followed while not dragging: the caller writes the backend on every
// `moved`, the backend then pushes a new value back, and binding both directions at
// once makes the handle stutter under the cursor.
Item {
  id: root

  property real value: 0
  property real step: 0.05
  property bool dragging: false
  property color fillColor: Color.popupAccent

  property real liveValue: 0
  readonly property real shownValue: dragging ? liveValue : Math.max(0, Math.min(1, value))

  signal moved(real value)

  implicitHeight: 18

  function commit(x) {
    var v = Math.max(0, Math.min(1, x / Math.max(1, track.width)));
    liveValue = v;
    root.moved(v);
  }

  function nudge(delta) {
    var v = Math.max(0, Math.min(1, shownValue + delta));
    liveValue = v;
    root.moved(v);
  }

  Rectangle {
    id: track

    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    height: 5
    radius: height / 2
    color: Color.popupBorder

    Rectangle {
      width: Math.round(parent.width * root.shownValue)
      height: parent.height
      radius: parent.radius
      color: root.fillColor
    }
  }

  Rectangle {
    id: handle

    width: 11
    height: 11
    radius: width / 2
    color: root.fillColor
    x: Math.round(track.width * root.shownValue) - width / 2
    anchors.verticalCenter: parent.verticalCenter
    scale: mouse.containsMouse || root.dragging ? 1.2 : 1.0

    Behavior on scale {
      NumberAnimation {
        duration: 80
      }
    }
  }

  MouseArea {
    id: mouse

    anchors.fill: parent
    anchors.margins: -4
    hoverEnabled: true

    onPressed: mouse => {
      root.dragging = true;
      root.commit(mouse.x);
    }
    onPositionChanged: mouse => {
      if (root.dragging)
        root.commit(mouse.x);
    }
    onReleased: root.dragging = false
    onCanceled: root.dragging = false
    onWheel: wheel => root.nudge(wheel.angleDelta.y > 0 ? root.step : -root.step)
  }
}
