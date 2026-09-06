import QtQuick
import qs.Commons

// A small caps header above a group of rows, with an optional right-aligned value
// (used for "OUTPUT      64%") and an optional rule above it.
Item {
  id: root

  property string title: ""
  property string value: ""
  property bool rule: false

  implicitWidth: parent ? parent.width : 0
  implicitHeight: label.implicitHeight + (rule ? 13 : 5) + 4

  Rectangle {
    visible: root.rule
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: 1
    color: Color.popupBorder
    opacity: 0.6
  }

  Text {
    id: label

    anchors.left: parent.left
    anchors.leftMargin: 6
    anchors.bottom: parent.bottom
    text: root.title.toUpperCase()
    color: Color.popupMuted
    font.family: Style.fontFamily
    font.pixelSize: Style.fontSize - 2
    font.bold: true
  }

  Text {
    anchors.right: parent.right
    anchors.rightMargin: 6
    anchors.baseline: label.baseline
    visible: root.value !== ""
    text: root.value
    color: Color.popupMuted
    font.family: Style.fontFamily
    font.pixelSize: Style.fontSize - 2
  }
}
