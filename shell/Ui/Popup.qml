import QtQuick
import QtQuick.Shapes
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
//   * Keyboard focus is on-demand, which is enough for Escape and for a text field
//     inside a panel. It is a constant rather than a binding on `visible`: bound, the
//     surface mapped while the binding still read None and never took focus, so Escape
//     did nothing. A hidden window has no surface to hold focus with, so there is
//     nothing to switch off.
//
//     Not Exclusive, which this was until it was measured. Exclusive is an input grab in
//     Hyprland and not merely a keyboard one: with a panel open the bar stopped getting
//     pointer events at all -- no hover highlight, and a click on another widget going
//     nowhere -- so moving between panels meant pressing Escape first every time. The
//     seam is invisible from the QML side, which is why it survived so long: nothing
//     errors, the bar simply goes deaf. OnDemand still takes real focus -- Escape
//     reaches the panel, and keeps reaching it after switching from one widget to
//     another -- and leaves the pointer alone.
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

  // Joined, the panel hangs from the bar as one shape with it: no gap, the bar's colour,
  // and a concave curve where each side meets the bar's bottom edge. The bar decides --
  // a solid panel joined to a transparent bar would be hanging from nothing -- and a
  // panel that is not joined floats as a bordered box.
  readonly property bool joined: anchorWindow ? anchorWindow.joinsPanels === true : false
  // The curves are drawn in strips either side of the panel body, so the window is that
  // much wider than the panel it shows.
  readonly property int fillet: joined ? Style.radius : 0
  readonly property int gap: joined ? 0 : Style.popupGap
  // Where the bar starts on its screen. The bar is held off the edges by a margin, and
  // the anchor's position below is measured inside the bar, not on the screen; without
  // this every panel sat that margin left of the widget it belongs to.
  readonly property int barLeft: (anchorWindow && anchorWindow.margins) ? anchorWindow.margins.left : 0

  visible: false
  screen: anchorWindow ? anchorWindow.screen : null

  WlrLayershell.namespace: "desktop-panel"
  // Above the bar's Top layer, so the panel is never drawn under it, and above the
  // catcher window, which is what makes the catcher safe to stretch full-screen.
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

  // Anchored into the top-left of what the bar does not occupy, then pushed across with
  // a margin. ExclusionMode.Normal with a zero zone is the combination that reserves no
  // space of its own while still respecting the bar's.
  anchors.top: true
  anchors.left: true
  exclusionMode: ExclusionMode.Normal
  exclusiveZone: 0

  color: "transparent"

  implicitWidth: root.contentWidth + root.fillet * 2
  // A long device list must not run off the bottom of the screen. Rounded because the
  // panel can move between monitors of different scale, and fractional sizes there
  // blur text.
  implicitHeight: {
    var avail = 600;
    if (screen)
      avail = screen.height - Style.barInset - Style.barSize - root.gap - Style.popupMargin * 2;
    return Math.round(Math.max(80, Math.min(root.contentHeight, avail)));
  }

  margins.top: root.gap

  // Centred under the widget, kept on screen at either end. A joined panel also keeps its
  // curves off the bar's rounded ends: beyond the straight part of the bar's bottom edge
  // a curve would run out into the air beside the corner.
  function reposition() {
    if (!anchorItem || !anchorWindow)
      return;

    var centre = root.barLeft + anchorItem.mapToItem(null, anchorItem.width / 2, 0).x;
    var screenWidth = screen ? screen.width : anchorWindow.width + root.barLeft * 2;
    var edge = root.joined ? root.barLeft + Style.radius + root.fillet : Style.popupMargin;
    var left = Math.max(edge, Math.min(centre - root.contentWidth / 2, screenWidth - root.contentWidth - edge));
    margins.left = Math.round(left - root.fillet);
  }

  // Joining changes the window's width and the edges it has to keep clear of, so the
  // position is stale the moment the bar's transparency flips.
  onJoinedChanged: reposition()

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
    visible: !root.joined
    anchors.fill: parent
    color: Color.popupBackground
    border.width: 1
    border.color: Color.popupBorder
    radius: Style.radius
  }

  // Joined: the body and its two curves as one filled outline. In the bar's colour, not
  // the panel's -- Catppuccin and Nord give the bar its own background, and any difference
  // shows as a seam. No border, because the bar has none for it to continue.
  Shape {
    id: joinShape

    visible: root.joined
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      id: outline

      readonly property real w: joinShape.width
      readonly property real h: joinShape.height
      readonly property real f: root.fillet
      readonly property real r: Style.radius

      fillColor: Color.barBackground
      strokeWidth: -1

      // Clockwise from the top-left, along the bar's bottom edge. The two curves at the
      // top turn against the corners at the bottom, which is what makes them concave.
      startX: 0
      startY: 0
      PathLine {
        x: outline.w
        y: 0
      }
      PathArc {
        x: outline.w - outline.f
        y: outline.f
        radiusX: outline.f
        radiusY: outline.f
        direction: PathArc.Counterclockwise
      }
      PathLine {
        x: outline.w - outline.f
        y: outline.h - outline.r
      }
      PathArc {
        x: outline.w - outline.f - outline.r
        y: outline.h
        radiusX: outline.r
        radiusY: outline.r
      }
      PathLine {
        x: outline.f + outline.r
        y: outline.h
      }
      PathArc {
        x: outline.f
        y: outline.h - outline.r
        radiusX: outline.r
        radiusY: outline.r
      }
      PathLine {
        x: outline.f
        y: outline.f
      }
      PathArc {
        x: 0
        y: 0
        radiusX: outline.f
        radiusY: outline.f
        direction: PathArc.Counterclockwise
      }
    }
  }

  // FocusScope rather than a plain Item: the panel is the keyboard focus while it is
  // open, and a text field inside one needs somewhere for that focus to land.
  FocusScope {
    id: body

    anchors.fill: parent
    anchors.topMargin: Style.popupPadding
    anchors.bottomMargin: Style.popupPadding
    anchors.leftMargin: Style.popupPadding + root.fillet
    anchors.rightMargin: Style.popupPadding + root.fillet
    focus: true

    Keys.onPressed: event => root.keyPressed(event)
    Keys.onEscapePressed: root.close()
  }
}
