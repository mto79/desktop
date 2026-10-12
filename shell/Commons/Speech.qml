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
  // Which model a spoken sentence goes to when the list does not know it, and where that
  // is: "cloud" (Anthropic), "remote" (the VPN server), "local", or "none". desktop-voice writes it;
  // asked afresh every minute, since a VPN coming up or going down changes the answer.
  property string model: ""
  property string modelWhere: "none"
  readonly property string modelLine: modelWhere === "cloud" ? model + " · Anthropic, leaves this machine" : modelWhere === "remote" ? model + " · remote, over the VPN" : modelWhere === "local" ? model + " · on this machine" : "the list only, no model"

  property FileView modelFile: FileView {
    path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/desktop/voice/model"
    printErrors: false
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
      try {
        var which = JSON.parse(text());
        root.model = String(which.name || "");
        root.modelWhere = String(which.where || "none");
      } catch (error) {}
    }
  }

  property Process modelAsk: Process {
    command: ["desktop-voice", "model", "--json"]
    running: true
  }

  property Timer modelAgain: Timer {
    interval: 60000
    repeat: true
    running: true
    onTriggered: root.modelAsk.running = true
  }

  property Timer giveUp: Timer {
    interval: 45000
    onTriggered: root.state = ""
  }
}
