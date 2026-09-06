import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons

// A panel that drops under a bar widget.
//
// This is a layer-shell surface, not an xdg_popup. A popup needs a seat grab to get
// click-outside dismissal, and that grab has to descend from a real click on the parent
// surface -- which meant a panel could only ever be opened by clicking its widget, and
// never from a keybinding, a script, or IPC. A layer surface has no such rule, so
// dismissal and keyboard focus become this shell's job instead of the compositor's:
//
//   * PopupHost puts a transparent catcher window under the open panel for
//     click-outside. It deliberately does not cover the bar, so clicking a different
//     bar widget still reaches that widget rather than being eaten.
//   * Keyboard focus is exclusive, which is what makes Escape work and what a text
//     field inside a panel would need. It is a constant rather than a binding on
//     `visible`: bound, the surface mapped while the binding still read None and never
//     took focus, so Escape did nothing. A hidden window has no surface to hold focus
//     with, so there is nothing to switch off.
PanelWindow {
  id: root

  // The bar widget this hangs under. Reassigned by PopupHost as the user clicks
  // different widgets, which also moves the window onto that widget's screen.
  property Item anchorItem: null

  // Content height the panel would like; clamped against the screen below.
  property int contentHeight: 0
  property int contentWidth: Style.popupWidth

  default property alias content: body.data

  // Not named `closed`: PanelWindow already declares that signal, and overriding it is
  // both a QML warning and ambiguous to read.
  signal dismissed

  // Every key the panel receives, before Escape is turned into a close. A panel that
  // accepts the event keeps it -- which is how the passphrase prompt makes Escape mean
  // "cancel the prompt" instead of "close the panel".
  signal keyPressed(var event)

  readonly property var anchorWindow: (anchorItem && anchorItem.QsWindow) ? anchorItem.QsWindow.window : null

  visible: false
  screen: anchorWindow ? anchorWindow.screen : null

  WlrLayershell.namespace: "desktop-panel"
  // Above the bar's Top layer, so the panel is never drawn under it, and above the
  // catcher window, which is what makes the catcher safe to stretch full-screen.
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

  // Anchored into the top-left of what the bar does not occupy, then pushed across with
  // a margin. ExclusionMode.Normal with a zero zone is the combination that reserves no
  // space of its own while still respecting the bar's.
  anchors.top: true
  anchors.left: true
  exclusionMode: ExclusionMode.Normal
  exclusiveZone: 0

  color: "transparent"

  implicitWidth: root.contentWidth
  // A long device list must not run off the bottom of the screen. Rounded because the
  // panel can move between monitors of different scale, and fractional sizes there
  // blur text.
  implicitHeight: {
    var avail = 600;
    if (screen)
      avail = screen.height - Style.barSize - Style.popupGap - Style.popupMargin * 2;
    return Math.round(Math.max(80, Math.min(root.contentHeight, avail)));
  }

  margins.top: Style.popupGap

  // Centred under the widget, kept on screen at either end.
  function reposition() {
    if (!anchorItem || !anchorWindow)
      return;

    var centre = anchorItem.mapToItem(null, anchorItem.width / 2, 0).x;
    var limit = (screen ? screen.width : anchorWindow.width) - width - Style.popupMargin;
    margins.left = Math.round(Math.max(Style.popupMargin, Math.min(centre - width / 2, limit)));
  }

  // The anchor moves under a mapped panel -- the bar reflows whenever a window title
  // grows or an indicator appears. An xdg_popup followed its anchor for free; here the
  // position has to be re-derived, and doing it on a slow timer is both simpler and
  // more reliable than trying to bind through every parent in the chain.
  Timer {
    interval: 250
    repeat: true
    running: root.visible
    onTriggered: root.reposition()
  }

  function open() {
    reposition();
    visible = true;
    body.forceActiveFocus();
  }

  function close() {
    visible = false;
  }

  // Hand the keyboard back to the panel itself. A panel that gave focus to a field has
  // to call this when the field goes away, or every later key -- Escape included --
  // keeps going to an input nobody can see.
  function takeFocus() {
    body.forceActiveFocus();
  }

  onVisibleChanged: {
    if (visible)
      reposition();
    else
      root.dismissed();
  }

  Rectangle {
    anchors.fill: parent
    color: Color.popupBackground
    border.width: 1
    border.color: Color.popupBorder
    radius: Style.radius
  }

  // FocusScope rather than a plain Item: the panel is the keyboard focus while it is
  // open, and a text field inside one needs somewhere for that focus to land.
  FocusScope {
    id: body

    anchors.fill: parent
    anchors.margins: Style.popupPadding
    focus: true

    Keys.onPressed: event => root.keyPressed(event)
    Keys.onEscapePressed: root.close()
  }
}
