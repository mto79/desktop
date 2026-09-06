import QtQuick
import qs.Commons

// Owns one instance of each panel and re-anchors it to whichever bar widget was clicked.
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

  property string activeId: ""

  function register(id, panel) {
    var next = {};
    for (var k in panels)
      next[k] = panels[k];
    next[id] = panel;
    panels = next;
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

  // Called by a widget's click handler: popups.toggle("bluetooth", this)
  function toggle(id, item) {
    var panel = panelFor(id);
    if (!panel || !item)
      return;

    if (activeId === id && panel.visible) {
      close();
      return;
    }

    var wasOpen = activeId !== "";
    close();

    panel.anchorItem = item;

    // Only one seat grab exists compositor-wide, so tearing one down and creating
    // another in the same event-loop turn confuses QtWayland's popup bookkeeping.
    // Re-anchoring also needs a turn to re-parent the window onto the new screen.
    activeId = id;
    if (wasOpen)
      Qt.callLater(function () {
        if (root.activeId === id)
          panel.open();
      });
    else
      panel.open();
  }

  // A panel closing on its own (click outside, or the compositor dropping the grab)
  // has to be reflected here or the next click on the same widget would be treated as
  // a close and do nothing.
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
}
