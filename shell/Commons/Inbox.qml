pragma Singleton

import QtQuick

// The notifications that are still around, and whether new ones may interrupt.
//
// The server that receives them lives in Notifications.qml, which draws the toasts. The
// bell in the bar and the panel under it are elsewhere in the tree and need the same
// list, so it is kept here: a singleton from qs.Commons is the one kind of object every
// part of the shell sees the same instance of.
QtObject {
  id: root

  // Every notification still tracked, oldest first. Set by Notifications.qml; these are
  // the live objects, so an action on one is still an action the sender hears about.
  property var all: []

  // When each arrived, by id, in milliseconds. The notification itself does not say.
  // Reassigned on every arrival so that what is bound to it notices.
  property var arrivedAt: ({})

  function noteArrival(id) {
    var next = {};
    for (var i = 0; i < all.length; i++)
      if (arrivedAt[all[i].id] !== undefined)
        next[all[i].id] = arrivedAt[all[i].id];
    next[id] = Date.now();
    arrivedAt = next;
  }

  // Silenced notifications are still received and kept -- nothing is lost, it just does
  // not interrupt. quietUntil is when that ends by itself, or 0 for "until turned off":
  // do-not-disturb that has to be remembered is do-not-disturb that is still on the next
  // morning.
  property bool doNotDisturb: false
  property double quietUntil: 0

  function quiet(minutes) {
    doNotDisturb = true;
    quietUntil = minutes > 0 ? Date.now() + minutes * 60000 : 0;
  }

  function unquiet() {
    doNotDisturb = false;
    quietUntil = 0;
  }

  function toggleQuiet() {
    if (doNotDisturb)
      unquiet();
    else
      quiet(0);
    return doNotDisturb;
  }

  property Timer quietTimer: Timer {
    interval: 15000
    repeat: true
    running: root.doNotDisturb && root.quietUntil > 0
    onTriggered: if (Date.now() >= root.quietUntil)
      root.unquiet()
  }
}
