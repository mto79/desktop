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
}
