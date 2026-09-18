import QtQuick
import qs.Commons

// One label and value, half a panel wide, for the two-column Grid of figures under a
// PanelHero. Red when the value is worth worrying about, faded when it is only context.
Item {
  id: root

  property string label: ""
  property string value: ""
  property bool warn: false
  property bool muted: false

  width: parent ? parent.width / 2 : 0
  height: 22

  Text {
    anchors.left: parent.left
    anchors.leftMargin: 6
    anchors.verticalCenter: parent.verticalCenter
    text: root.label
    color: Color.popupMuted
    font.family: Style.fontFamily
    font.pixelSize: Style.fontSize - 1
  }

  Text {
    anchors.right: parent.right
    anchors.rightMargin: 10
    anchors.verticalCenter: parent.verticalCenter
    text: root.value
    color: root.warn ? Color.popupUrgent : (root.muted ? Color.popupMuted : Color.popupText)
    font.family: Style.fontFamily
    font.pixelSize: Style.fontSize - 1
  }
}
