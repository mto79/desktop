import QtQuick
import qs.Commons

// A line that says there is nothing, so an empty card reads as an answer.
Text {
  width: parent ? parent.width : 0
  color: Color.popupMuted
  font.family: Style.fontFamily
  font.pixelSize: Style.fontSize
  wrapMode: Text.WordWrap
}
