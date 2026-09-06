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
// No keyboard focus either way. Whether the pointer passes through is up to the
// caller: an OSD is scenery, a notification has buttons on it.
PanelWindow {
  id: root

  // Vertical edge plus an optional horizontal one: "bottom", "top", "top-right",
  // "bottom-left". Leaving the horizontal half out centres it there, and "center"
  // anchors nothing at all, which centres it on both axes.
  property string position: "bottom"
  property int margin: 80
  // Notifications need clicks; an OSD must not eat them.
  property bool interactive: false
  // Distinct per consumer, so `hyprctl layers` and any layerrule can tell an OSD from
  // a notification stack.
  property string surfaceNamespace: "desktop-surface"
  // A launcher has to take the keyboard; an OSD and a toast must not.
  property bool focusable: false

  readonly property bool centered: position === "center"
  readonly property bool atTop: position.indexOf("top") === 0
  readonly property bool atLeft: position.indexOf("left") !== -1
  readonly property bool atRight: position.indexOf("right") !== -1

  default property alias content: body.data

  WlrLayershell.namespace: root.surfaceNamespace
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: root.focusable ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

  anchors.top: !root.centered && root.atTop
  anchors.bottom: !root.centered && !root.atTop
  anchors.left: !root.centered && root.atLeft
  anchors.right: !root.centered && root.atRight
  // Reserve nothing, but stay clear of the bar's own zone.
  exclusionMode: ExclusionMode.Normal
  exclusiveZone: 0

  margins.top: (!root.centered && root.atTop) ? root.margin : 0
  margins.bottom: (!root.centered && !root.atTop) ? root.margin : 0
  margins.left: (!root.centered && root.atLeft) ? root.margin : 0
  margins.right: (!root.centered && root.atRight) ? root.margin : 0

  color: "transparent"
  mask: root.interactive ? null : passThrough

  // An empty region is what makes the pointer pass straight through; null hands input
  // back to the window.
  Region {
    id: passThrough
  }

  implicitWidth: body.implicitWidth
  implicitHeight: body.implicitHeight

  Item {
    id: body

    anchors.fill: parent
    implicitWidth: childrenRect.width
    implicitHeight: childrenRect.height
  }
}
