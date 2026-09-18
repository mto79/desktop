import QtQuick
import qs.Commons

// The top of a panel: a large icon, a title with a status line in small capitals under
// it, and one number big on the right -- the level, the count, the percentage. What the
// panel is about, readable from across the desk. Every panel opens with one, so they all
// read the same way: glance at the right edge, then at the line under the title.
Item {
  id: root

  property string icon: ""
  property string title: ""
  property string status: ""
  property string value: ""

  property color iconColor: Color.popupText
  property color statusColor: Color.popupMuted
  property color valueColor: Color.popupText

  // A muted volume, say: still the number, visibly not in force.
  property bool struck: false
  // Turning while something runs -- a check, a capture.
  property bool spinning: false
  // The icon as a button: the speaker that mutes, the microphone that mutes.
  property bool iconClickable: false

  signal iconClicked

  width: parent ? parent.width : 0
  height: 56

  Text {
    id: glyph

    anchors.left: parent.left
    anchors.leftMargin: 6
    anchors.verticalCenter: parent.verticalCenter
    text: root.icon
    color: root.iconColor
    font.family: Style.fontFamily
    font.pixelSize: Style.iconSize * 2.4

    RotationAnimation on rotation {
      running: root.spinning
      from: 0
      to: 360
      duration: 1200
      loops: Animation.Infinite
      onStopped: glyph.rotation = 0
    }

    MouseArea {
      anchors.fill: parent
      enabled: root.iconClickable
      cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
      onClicked: root.iconClicked()
    }
  }

  Column {
    anchors.left: glyph.right
    anchors.leftMargin: 12
    anchors.right: number.left
    anchors.rightMargin: 8
    anchors.verticalCenter: parent.verticalCenter
    spacing: 2

    Text {
      width: parent.width
      text: root.title
      color: Color.popupText
      font.family: Style.fontFamily
      font.pixelSize: Style.fontSize + 2
      font.bold: true
      elide: Text.ElideRight
    }

    Text {
      width: parent.width
      visible: root.status !== ""
      text: root.status.toUpperCase()
      color: root.statusColor
      font.family: Style.fontFamily
      font.pixelSize: Style.fontSize - 2
      font.bold: true
      font.letterSpacing: 1
      elide: Text.ElideRight
    }
  }

  Text {
    id: number

    anchors.right: parent.right
    anchors.rightMargin: 6
    anchors.verticalCenter: parent.verticalCenter
    text: root.value
    color: root.valueColor
    font.family: Style.fontFamily
    font.pixelSize: Style.fontSize * 2.2
    font.bold: true
    font.strikeout: root.struck
  }
}
