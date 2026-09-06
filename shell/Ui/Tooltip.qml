import QtQuick
import Quickshell
import qs.Commons

// The hover label that sits under a bar widget.
//
// Deliberately not a Popup: a tooltip must never take focus or eat the click that
// follows it, so this has no seat grab -- which is also why it can be shown without a
// preceding click, unlike the panels. The input mask is empty for the same reason: the
// window is scenery, and the pointer passes straight through it.
PopupWindow {
  id: root

  property Item anchorItem: null
  property string text: ""

  anchor.item: root.anchorItem
  anchor.edges: Edges.Bottom
  anchor.gravity: Edges.Bottom
  anchor.adjustment: PopupAdjustment.Slide
  anchor.margins.top: Style.popupGap

  grabFocus: false
  color: "transparent"
  mask: Region {}

  implicitWidth: frame.implicitWidth
  implicitHeight: frame.implicitHeight

  Rectangle {
    id: frame

    implicitWidth: label.implicitWidth + Style.tooltipPaddingH * 2
    implicitHeight: label.implicitHeight + Style.tooltipPaddingV * 2

    anchors.fill: parent
    color: Color.tooltipBackground
    border.width: 1
    border.color: Color.tooltipBorder
    radius: Style.radius

    Text {
      id: label

      anchors.centerIn: parent
      width: Math.min(implicitWidth, Style.tooltipMaxWidth)
      text: root.text
      textFormat: Text.PlainText
      color: Color.tooltipText
      font.family: Style.fontFamily
      font.pixelSize: Style.fontSize
      wrapMode: Text.WordWrap
      horizontalAlignment: Text.AlignLeft
    }
  }
}
