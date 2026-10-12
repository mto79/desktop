import QtQuick
import QtQuick.Layouts
import qs.Commons

// The notice over a page that is showing invented numbers.
//
// A tab with no source would be an empty page, so it shows sample data instead -- which
// is only honest if it says so where it cannot be missed, and says what would make it
// real. This is that: across the top of the page, in the caution colour, with the steps.
Rectangle {
  id: notice

  property var how: []

  Layout.fillWidth: true
  implicitHeight: lines.implicitHeight + Style.popupPadding * 2
  radius: Style.radius
  color: Qt.rgba(Color.caution.r, Color.caution.g, Color.caution.b, 0.1)
  border.width: 1
  border.color: Qt.rgba(Color.caution.r, Color.caution.g, Color.caution.b, 0.6)

  Column {
    id: lines

    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: Style.popupPadding
    spacing: 4

    Text {
      text: "\u{f0026}  Sample data  ·  nothing on this page is yours yet"
      color: Color.caution
      font.family: Style.fontFamily
      font.pixelSize: Style.fontSize + 1
      font.weight: Style.barLabelWeight
    }
    Repeater {
      model: notice.how

      delegate: Text {
        required property var modelData

        width: lines.width
        text: modelData
        textFormat: Text.PlainText
        color: Color.popupText
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSize - 1
        wrapMode: Text.WordWrap
      }
    }
  }
}
