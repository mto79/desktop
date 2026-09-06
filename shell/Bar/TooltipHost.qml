import QtQuick
import qs.Commons
import qs.Ui

// Owns the single tooltip window and decides when it is on screen.
//
// One instance for the same reason PopupHost is one instance: the tooltip re-anchors
// to whichever widget the pointer is over, and re-anchoring is what moves it onto that
// widget's monitor. A per-monitor copy would also mean several of them racing to be
// the one that is visible.
Item {
  id: root

  // The widget currently showing a tooltip, and the one waiting out the delay.
  property Item current: null
  property Item pending: null
  property string pendingText: ""

  // Called from BarItem on hover. Re-requesting for the widget already showing just
  // updates the text, so a tooltip over a ticking clock does not flicker.
  function request(item, text) {
    if (!item || text === "")
      return;

    if (current === item) {
      tooltip.text = text;
      return;
    }

    pending = item;
    pendingText = text;
    // Once one tooltip is up, moving along the bar should not re-serve the delay.
    delayTimer.interval = current ? 0 : Style.tooltipDelay;
    delayTimer.restart();
  }

  function release(item) {
    if (pending === item) {
      delayTimer.stop();
      pending = null;
    }
    if (current === item)
      hide();
  }

  function hide() {
    current = null;
    tooltip.visible = false;
  }

  Timer {
    id: delayTimer

    repeat: false
    onTriggered: {
      if (!root.pending)
        return;

      var item = root.pending;
      root.pending = null;
      tooltip.text = root.pendingText;

      // Re-anchoring a mapped popup and showing it in the same turn confuses the
      // compositor's bookkeeping, the same way it does for panels.
      if (tooltip.visible) {
        tooltip.visible = false;
        root.current = item;
        Qt.callLater(function () {
          if (root.current !== item)
            return;
          tooltip.anchorItem = item;
          tooltip.visible = true;
        });
      } else {
        root.current = item;
        tooltip.anchorItem = item;
        tooltip.visible = true;
      }
    }
  }

  Tooltip {
    id: tooltip
  }
}
