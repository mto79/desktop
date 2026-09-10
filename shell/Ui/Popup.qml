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

  // How much of the panel is shown, top down: 0 on opening, 1 once it has grown out of
  // the bar. The window is mapped at its full size from the first frame and only what is
  // drawn inside it grows. Animating the window's own height instead would resize a
  // layer surface every frame, each one a round trip to the compositor, and it stutters.
  property real reveal: 1

  NumberAnimation {
    id: revealAnimation

    target: root
    property: "reveal"
    from: 0
    to: 1
    duration: Style.panelRevealDuration
    easing.type: Easing.OutCubic
  }

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

  // Only opening is animated. Closing stays immediate, so dismissal, focus and
  // PopupHost's idea of which panel is open never have to wait on a panel still
  // folding away.
  function open() {
    reposition();
    reveal = 0;
    revealPending = true;
    visible = true;
    body.forceActiveFocus();
  }

  function close() {
    revealPending = false;
    revealAnimation.stop();
    visible = false;
    reveal = 1;
  }

  // Set by open() and cleared once the reveal has started.
  property bool revealPending: false

  function startReveal() {
    revealPending = false;
    revealAnimation.restart();
  }

  // The reveal starts on the panel's first frame, not in open(). Measured from open() to
  // that first frame it took 103-127ms on every open, warm or cold -- mapping a layer
  // surface is not free -- and a 180ms reveal started in open() was already 47-67% done
  // before anything was on screen. The panel simply appeared, most of the way open.
  Connections {
    target: revealed.Window.window
    enabled: root.revealPending
    function onFrameSwapped() {
      root.startReveal();
    }
  }

  // A panel whose frame signal never arrives must not stay at reveal 0, which draws
  // nothing at all: start regardless, well after a normal first frame would have come.
  Timer {
    interval: 300
    running: root.revealPending
    onTriggered: root.startReveal()
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

  // Everything the panel draws, clipped to the part revealed so far. The contents keep
  // their full-size layout underneath and are uncovered rather than squeezed, so nothing
  // reflows while the panel grows.
  Item {
    id: revealed

    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    height: Math.round(parent.height * root.reveal)
    clip: true

    // The outline follows the revealed height, so the bottom corners travel down with
    // it -- but never shorter than its curves and corners, which would fold back on
    // themselves. The clip hides that minimum for the first frame or two.
    readonly property real shapeHeight: Math.max(root.fillet + Style.radius * 2, height)

    Rectangle {
      visible: !root.joined
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      height: revealed.shapeHeight
      color: Color.popupBackground
      border.width: 1
      border.color: Color.popupBorder
      radius: Style.radius
    }

    // Joined: the body and its two curves as one filled outline. In the bar's colour, not
    // the panel's -- Catppuccin and Nord give the bar its own background, and any
    // difference shows as a seam. No border, because the bar has none for it to continue.
    Shape {
      id: joinShape

      visible: root.joined
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      height: revealed.shapeHeight
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
    //
    // Sized against the window, not the revealed area, so the contents are laid out at
    // full size from the start.
    FocusScope {
      id: body

      x: Style.popupPadding + root.fillet
      y: Style.popupPadding
      width: revealed.width - (Style.popupPadding + root.fillet) * 2
      height: revealed.parent.height - Style.popupPadding * 2
      focus: true

      Keys.onPressed: event => root.keyPressed(event)
      Keys.onEscapePressed: root.close()
    }
  }
}
