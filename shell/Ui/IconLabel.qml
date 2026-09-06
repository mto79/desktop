import QtQuick
import QtQuick.Layouts
import qs.Commons

// A nerd-font glyph with optional text beside it. The two are sized independently:
// glyphs in most nerd fonts render a touch small next to text at the same point size.
RowLayout {
  id: root

  property string icon: ""
  property string text: ""
  property color color: Color.barText
  property int iconSize: Style.iconSize
  property int fontSize: Style.fontSize

  spacing: root.icon !== "" && root.text !== "" ? 6 : 0

  Text {
    visible: root.icon !== ""
    text: root.icon
    color: root.color
    font.family: Style.fontFamily
    font.pixelSize: root.iconSize
    verticalAlignment: Text.AlignVCenter
  }

  Text {
    visible: root.text !== ""
    text: root.text
    color: root.color
    font.family: Style.fontFamily
    font.pixelSize: root.fontSize
    verticalAlignment: Text.AlignVCenter
  }
}
