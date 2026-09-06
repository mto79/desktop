import QtQuick
import qs.Commons

// One clickable row inside a panel: optional leading glyph, a label with an optional
// second line, and a trailing slot for a badge or action button.
//
// The hover highlight lives here rather than in each panel so every list looks the
// same, and so a row can be highlighted by something other than the mouse later.
Item {
  id: root

  property string icon: ""
  // An image path, for rows whose icon is a file rather than a font glyph. Takes the
  // same slot; whichever one is set wins.
  property string iconSource: ""
  property string label: ""
  property string sublabel: ""
  // Marks the row as the current one (active sink, connected network). Distinct from
  // hover, and both can be true at once.
  property bool active: false
  // The keyboard cursor. Both this and `active` can be true at once, so it reads as an
  // outline rather than another fill.
  property bool cursor: false
  property bool enabled: true
  property color accentColor: Color.popupAccent

  // Trailing content, e.g. a battery percentage or a forget button.
  default property alias trailing: trailingSlot.data

  readonly property bool hovered: mouse.containsMouse

  signal clicked
  signal rightClicked

  implicitWidth: parent ? parent.width : 0
  implicitHeight: Math.max(Style.rowHeight, column.implicitHeight + 8)

  Rectangle {
    anchors.fill: parent
    radius: Style.radius
    color: root.active ? Color.popupSelected : (root.hovered && root.enabled ? Color.popupHover : "transparent")
    border.width: root.cursor ? 1 : 0
    border.color: Color.popupAccent

    Behavior on color {
      ColorAnimation {
        duration: 80
      }
    }
  }

  Image {
    id: picture

    visible: root.iconSource !== ""
    anchors.left: parent.left
    anchors.leftMargin: 6
    anchors.verticalCenter: parent.verticalCenter
    width: Style.iconSize + 5
    height: width
    source: root.iconSource
    sourceSize.width: width * 2
    sourceSize.height: width * 2
    fillMode: Image.PreserveAspectFit
    smooth: true
    asynchronous: true
    opacity: root.enabled ? 1.0 : 0.4
  }

  Text {
    id: glyph

    visible: root.icon !== "" && root.iconSource === ""
    anchors.left: parent.left
    anchors.leftMargin: 6
    anchors.verticalCenter: parent.verticalCenter
    text: root.icon
    color: root.active ? root.accentColor : Color.popupText
    font.family: Style.fontFamily
    font.pixelSize: Style.iconSize
    opacity: root.enabled ? 1.0 : 0.4
  }

  Column {
    id: column

    anchors.left: picture.visible ? picture.right : (glyph.visible ? glyph.right : parent.left)
    anchors.leftMargin: (picture.visible || glyph.visible) ? 10 : 6
    anchors.right: trailingSlot.left
    anchors.rightMargin: 8
    anchors.verticalCenter: parent.verticalCenter
    spacing: 1

    Text {
      width: parent.width
      text: root.label
      textFormat: Text.PlainText
      color: root.active ? root.accentColor : Color.popupText
      font.family: Style.fontFamily
      font.pixelSize: Style.fontSize
      elide: Text.ElideRight
      opacity: root.enabled ? 1.0 : 0.4
    }

    Text {
      visible: root.sublabel !== ""
      width: parent.width
      text: root.sublabel
      textFormat: Text.PlainText
      color: Color.popupMuted
      font.family: Style.fontFamily
      font.pixelSize: Style.fontSize - 2
      elide: Text.ElideRight
    }
  }

  Item {
    id: trailingSlot

    anchors.right: parent.right
    anchors.rightMargin: 6
    anchors.verticalCenter: parent.verticalCenter
    implicitWidth: childrenRect.width
    implicitHeight: childrenRect.height
    width: implicitWidth
    height: implicitHeight
  }

  MouseArea {
    id: mouse

    anchors.fill: parent
    hoverEnabled: true
    enabled: root.enabled
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: mouse => {
      if (mouse.button === Qt.RightButton)
        root.rightClicked();
      else
        root.clicked();
    }
  }
}
