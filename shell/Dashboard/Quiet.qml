import QtQuick
import qs.Commons

// A line that says there is nothing, so an empty card reads as an answer.
//
// Plain text, always: much of what is written here comes from elsewhere -- a device's own
// name on the network, a Wi-Fi network's -- and Text would otherwise take anything with a
// tag in it for HTML and render it.
Text {
  width: parent ? parent.width : 0
  textFormat: Text.PlainText
  color: Color.popupMuted
  font.family: Style.fontFamily
  font.pixelSize: Style.fontSize
  wrapMode: Text.WordWrap
}
