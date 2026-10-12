pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// What the desktop is saying or hearing right now, for whatever draws it.
//
// desktop-say and desktop-voice keep one small file for as long as there is something to
// show ($XDG_RUNTIME_DIR/desktop/say/now). The card in the corner and the dashboard both
// draw from it, so it is read once, here.
//
//   state   "" (nothing), "listening", "preparing" or "speaking"
//   line    what is being said, or what was understood
QtObject {
  id: root

  property string state: ""
  property string line: ""

  readonly property bool active: state !== ""
  readonly property bool listening: state === "listening"
  // Anything but the wait for the voice is drawn as lively.
  readonly property bool lively: state === "speaking" || state === "listening"

  property FileView now: FileView {
    path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/desktop/say/now"
    printErrors: false
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
      try {
        var said = JSON.parse(text());
        root.line = String(said.text || "");
        root.state = String(said.state || "");
        root.giveUp.restart();
      } catch (error) {
        root.state = "";
      }
    }
    onLoadFailed: root.state = ""
  }

  // If whatever was speaking died without tidying up, nothing must go on saying so.
  property Timer giveUp: Timer {
    interval: 45000
    onTriggered: root.state = ""
  }
}
