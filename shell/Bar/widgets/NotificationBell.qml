import QtQuick
import qs.Commons
import qs.Ui

// How many notifications are waiting, and whether new ones are being held back.
//
// A toast is on screen for six seconds and was then gone for good: look away and there
// was no way to know what it had said, or that it had been there. They are kept now, and
// this is the count of what is kept. Always shown, muted when there is nothing: a control
// that only appears when it has something to say is one you have to remember exists, and
// this is also where do-not-disturb is.
BarItem {
  id: root

  readonly property int count: Inbox.count

  tooltip: {
    var lines = [count === 0 ? "No notifications" : count + (count === 1 ? " notification" : " notifications")];
    if (Inbox.doNotDisturb)
      lines.push("Do not disturb is on");
    lines.push("Right click: do not disturb");
    return lines.join("\n");
  }

  panelId: "notifications"

  onClicked: if (popups)
    popups.toggle(root.panelId, this)
  onRightClicked: Inbox.toggleQuiet()

  IconLabel {
    icon: Inbox.doNotDisturb ? "\u{f009b}" : (root.count > 0 ? "\u{f009a}" : "\u{f009c}")
    text: root.count > 0 ? String(root.count) : ""
    color: Inbox.doNotDisturb ? Color.barMuted : (root.count > 0 ? Color.barAccent : Color.barMuted)
  }
}
