pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// The keyboard shortcut behind a bar action, for its tooltip to mention.
//
// The table comes from desktop-shortcuts, which reads Hyprland's live bindings rather than
// anything written down here -- so a hint cannot drift from the key it names. It is read
// once at start and again whenever Hyprland reloads its config, which is when a binding can
// have changed.
//
// Widgets ask by what they do, not by name: the panel they open, or the command a click runs.
// An action nobody bound a key to simply has no hint.
Singleton {
  id: root

  property var table: ({
      "exec": {},
      "panel": {}
    })

  readonly property string dictation: table.dictation || ""

  // A command as a click would run it: a list, as Process takes, or the shell string a
  // shell.json module writes -- which CommandWidget wraps as ["bash", "-c", string].
  function forExec(command) {
    if (!command)
      return "";
    var text;
    if (Array.isArray(command))
      text = (command.length === 3 && command[0] === "bash" && command[1] === "-c") ? command[2] : command.join(" ");
    else
      text = String(command);
    return (root.table.exec && root.table.exec[text.trim()]) || "";
  }

  function forPanel(id) {
    return (id && root.table.panel && root.table.panel[id]) || "";
  }

  Process {
    id: reader

    command: ["desktop-shortcuts", "--json"]
    running: true

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          root.table = JSON.parse(text);
        } catch (e) {
          console.warn("Shortcuts: desktop-shortcuts printed unparseable JSON:", e);
        }
      }
    }
  }

  Connections {
    target: Hyprland

    function onRawEvent(event) {
      if (event.name === "configreloaded" && !reader.running)
        reader.running = true;
    }
  }
}
