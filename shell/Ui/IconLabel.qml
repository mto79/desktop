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

  // Set by the bar when the section this sits in has run out of room: the text goes and
  // the glyph stays. A label with no glyph has nothing to fall back to, so it is left be.
  property bool compact: false
  readonly property bool textShown: root.text !== "" && !(root.compact && root.icon !== "")
  // What going compact gives back. Read off the text's implicit width, which Qt keeps
  // whether or not the text is drawn -- so this does not move when `compact` does, and
  // the bar can add it back to work out what the section would need at full size.
  readonly property real compactSaving: root.icon !== "" && root.text !== "" ? label.implicitWidth + 6 : 0

  spacing: root.icon !== "" && root.textShown ? 6 : 0

  Text {
    visible: root.icon !== ""
    text: root.icon
    color: root.color
    font.family: Style.fontFamily
    font.pixelSize: root.iconSize
    verticalAlignment: Text.AlignVCenter
  }

  Text {
    id: label

    visible: root.textShown
    text: root.text
    color: root.color
    font.family: Style.fontFamily
    font.pixelSize: root.fontSize
    verticalAlignment: Text.AlignVCenter
  }
}
