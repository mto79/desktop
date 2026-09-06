import QtQuick
import Quickshell
import qs.Commons

// A dropdown anchored under a bar widget.
//
// grabFocus gives compositor-managed click-outside dismissal: the popup becomes an
// xdg_popup with a seat grab, and Hyprland closes it when a click lands outside the
// grab set. Two consequences that shape the API:
//
//   * The parent bar surface is inside that grab set, so clicking a *different* bar
//     widget is delivered normally rather than dismissing. Only-one-open is therefore
//     PopupHost's job, not the compositor's.
//   * The grab needs a real click on the parent first. Opening one cold -- from a
//     keybinding or IPC, with no preceding click -- fails to map at all.
//
// grabFocus is read once at window creation, so it is a constant here and never toggled.
PopupWindow {
  id: root

  // The bar widget this hangs under. Reassigned by PopupHost as the user clicks
  // different widgets, which re-parents the window onto that widget's screen.
  property Item anchorItem: null

  // Content height the panel would like; clamped against the screen below.
  property int contentHeight: 0
  property int contentWidth: Style.popupWidth

  default property alias content: body.data

  // Not named `closed`: PopupWindow already declares that signal, and overriding it
  // is both a QML warning and ambiguous to read.
  signal dismissed

  anchor.item: root.anchorItem
  anchor.edges: Edges.Bottom
  anchor.gravity: Edges.Bottom
  // Slide along the screen edge rather than hanging off it. Slide never *shrinks*, so
  // the height clamp below still has to do its own work.
  anchor.adjustment: PopupAdjustment.Slide
  anchor.margins.top: Style.popupGap

  grabFocus: true
  color: Color.popupBackground

  implicitWidth: root.contentWidth
  // A long device list must not run off the bottom of the screen. Rounded because the
  // popup can move between monitors of different scale, and fractional sizes there
  // blur text.
  implicitHeight: {
    var avail = 600;
    if (anchorItem && anchorItem.QsWindow && anchorItem.QsWindow.window && anchorItem.QsWindow.window.screen)
      avail = anchorItem.QsWindow.window.screen.height - Style.barSize - Style.popupGap - Style.popupMargin * 2;
    return Math.round(Math.max(80, Math.min(root.contentHeight, avail)));
  }

  function open() {
    visible = true;
  }

  function close() {
    visible = false;
  }

  // The compositor can close this behind our back (any click outside the grab set), so
  // the window is the source of truth and the host is told, rather than the reverse.
  onVisibleChanged: if (!visible)
    root.dismissed()

  Rectangle {
    anchors.fill: parent
    color: "transparent"
    border.width: 1
    border.color: Color.popupBorder
    radius: Style.radius
    z: 1
  }

  Item {
    id: body

    anchors.fill: parent
    anchors.margins: Style.popupPadding
  }
}
