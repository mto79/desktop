import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons

// Owns one instance of each panel and re-anchors it to whichever bar widget was used.
//
// This lives in Bar.qml's root -- outside Variants -- so there is exactly ONE of each
// panel no matter how many monitors are attached. That is not just economy: the
// Bluetooth adapter's `discovering` flag and the Wi-Fi device's `scannerEnabled` are
// global, and a per-monitor copy of each panel would leave several writers fighting
// over them. One instance means one writer, and "opens on the monitor you clicked"
// falls out for free, because re-anchoring moves the window to that widget's screen.
Item {
  id: root

  // id -> Popup. Registered by the panels themselves so this file does not have to
  // know what exists.
  property var panels: ({})

  // id -> bar widget. Named anchorItems rather than anchors because Item.anchors is
  // final and cannot be shadowed. Lets a panel opened from IPC or a keybinding hang
  // under the widget it belongs to, with no click to tell us where that is. With
  // several monitors the last widget to register wins, which is as good an answer as
  // any for a request that names no screen.
  property var anchorItems: ({})

  property string activeId: ""

  function register(id, panel) {
    var next = {};
    for (var k in panels)
      next[k] = panels[k];
    next[id] = panel;
    panels = next;
  }

  function registerAnchor(id, item) {
    var next = {};
    for (var k in anchorItems)
      next[k] = anchorItems[k];
    next[id] = item;
    anchorItems = next;
  }

  function panelFor(id) {
    return panels[id] || null;
  }

  function close() {
    var current = panelFor(activeId);
    activeId = "";
    if (current)
      current.close();
  }

  // Called by a widget's click handler -- popups.toggle("bluetooth", this) -- or from
  // shell.qml's IPC handler, which passes no item and takes the registered anchor.
  function toggle(id, item) {
    var panel = panelFor(id);
    var anchor = item || anchorItems[id] || null;
    if (!panel || !anchor)
      return false;

    if (activeId === id && panel.visible) {
      close();
      return true;
    }

    close();
    panel.anchorItem = anchor;
    activeId = id;
    panel.open();
    return true;
  }

  // A panel closing on its own -- Escape, or a click on the catcher -- has to be
  // reflected here or the next click on the same widget would be treated as a close
  // and do nothing.
  function notifyClosed(id) {
    if (activeId === id)
      activeId = "";
  }

  // Unplugging a monitor destroys the BarPanel that owns the anchor item, leaving a
  // dangling anchor. Close rather than render against it.
  function anchorLost(id) {
    var panel = panelFor(id);
    if (panel && !panel.anchorItem)
      notifyClosed(id);
  }

  // Click-outside dismissal, which a layer surface does not get from the compositor.
  //
  // One per screen, so a click on any monitor closes the panel. Anchored to all four
  // edges but reserving nothing, which lays it out inside the area the bar does not
  // claim -- so a click on another bar widget still reaches that widget instead of
  // being swallowed here, the one nicety the old seat grab gave us for free.
  Variants {
    model: Quickshell.screens

    delegate: Component {
      PanelWindow {
        required property var modelData

        screen: modelData
        visible: root.activeId !== ""
        color: "transparent"

        WlrLayershell.namespace: "desktop-panel-catcher"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: 0

        MouseArea {
          anchors.fill: parent
          acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
          onPressed: root.close()
        }
      }
    }
  }
}
