pragma Singleton

import QtQuick

// Cross-cutting signals for the shell.
//
// Exists so a script can nudge one widget without restarting the whole shell: the
// IpcHandler in shell.qml is the single entry point, and widgets connect to the signal
// they care about. A widget cannot own the handler itself -- there is one widget
// instance per monitor, and IPC targets have to be unique.
QtObject {
  id: root

  // Something changed the set of available system updates.
  signal updatesChanged

  // Ask one command module to run its probe now rather than at its next interval, by the
  // id it has in shell.json. For a state that somebody is waiting on to change: an agent
  // that wants an answer should not take a polling interval to say so.
  signal widgetRefresh(string id)
}
