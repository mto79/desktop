import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons

// A surface placed against the screen rather than under a bar widget.
//
// Popup covers the "hangs off a widget" case; this is the other one -- an OSD, a toast,
// anything that belongs to a corner of the display. Anchoring a single edge lets the
// compositor centre it on the free axis, so "bottom" means bottom-centre without any
// arithmetic here.
//
// No keyboard focus and an empty input mask: this is scenery, and the pointer passes
// straight through it.
PanelWindow {
  id: root

  // "top" or "bottom".
  property string position: "bottom"
  property int margin: 80

  default property alias content: body.data

  WlrLayershell.namespace: "desktop-osd"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

  anchors.top: root.position === "top"
  anchors.bottom: root.position !== "top"
  // Reserve nothing, but stay clear of the bar's own zone.
  exclusionMode: ExclusionMode.Normal
  exclusiveZone: 0

  margins.top: root.position === "top" ? root.margin : 0
  margins.bottom: root.position !== "top" ? root.margin : 0

  color: "transparent"
  mask: Region {}

  implicitWidth: body.implicitWidth
  implicitHeight: body.implicitHeight

  Item {
    id: body

    anchors.fill: parent
    implicitWidth: childrenRect.width
    implicitHeight: childrenRect.height
  }
}
