import QtQuick
import qs.Commons

// A live audio level: a thin bar that jumps up with the sound and falls back slowly, the
// way a VU meter does, so a word registers as a word and not as a flicker.
//
// PipeWire's peak is linear amplitude, where speech sits around 0.05 and the bar would
// barely move. It is drawn on a decibel scale instead, -60 dB to 0, which is how loudness
// is heard: a quiet voice fills a third of it, a shout the lot.
Item {
  id: root

  // Linear peak, 0..1, straight from PwNodePeakMonitor.
  property real level: 0
  property string caption: ""
  property color fillColor: Color.popupAccent

  readonly property real scaled: level <= 0.001 ? 0 : Math.max(0, Math.min(1, (20 * Math.log(level) / Math.LN10 + 60) / 60))

  property real shown: 0

  // Fast up, slow down.
  onScaledChanged: if (scaled > shown)
    shown = scaled

  Timer {
    interval: 50
    repeat: true
    running: root.shown > 0 && root.visible
    onTriggered: root.shown = Math.max(root.scaled, root.shown - 0.04)
  }

  width: parent ? parent.width : 0
  height: 22

  Text {
    id: label

    anchors.left: parent.left
    anchors.leftMargin: 6
    anchors.verticalCenter: parent.verticalCenter
    width: 44
    text: root.caption !== "" ? root.caption : "level"
    color: Color.popupMuted
    font.family: Style.fontFamily
    font.pixelSize: Style.fontSize - 3
  }

  Rectangle {
    id: track

    anchors.left: label.right
    anchors.right: parent.right
    anchors.rightMargin: 6
    anchors.verticalCenter: parent.verticalCenter
    height: 4
    radius: 2
    color: Color.popupHover

    Rectangle {
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      width: parent.width * root.shown
      radius: 2
      // Red in the last sliver: clipping, where it stops being loud and starts breaking.
      color: root.shown > 0.95 ? Color.popupUrgent : root.fillColor
    }
  }
}
