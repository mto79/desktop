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
  // Who understands a spoken command the list does not know, how far that is from here,
  // and what has been learned from it. All of it desktop-voice's, asked for in one go
  // (desktop-voice state): at the start, every minute -- a VPN coming up changes the
  // answer -- and whenever desktop-voice says something changed.
  //
  //   mode        what you chose: "local", "vpn" or "cloud"
  //   model       the one that would be asked now, and modelWhere: "cloud" (Anthropic),
  //               "remote" (the VPN's server), "local", or "none"
  property string mode: "vpn"
  property string model: ""
  property string modelWhere: "none"
  property bool cloudKey: false
  property bool vpnConfigured: false
  property bool vpnReachable: false
  property var models: ({})
  property var yours: []
  property var learned: []
  property var missed: []

  readonly property string whereLine: modelWhere === "cloud" ? "at Anthropic · the sentence leaves this machine" : modelWhere === "remote" ? "over the VPN · leaves this machine" : modelWhere === "local" ? "on this machine" : "no model · the list only"
  readonly property string modelLine: (model !== "" ? model + " · " : "") + whereLine
  readonly property color modelTone: modelWhere === "cloud" ? Color.popupUrgent : modelWhere === "remote" ? Color.caution : Color.good
  // The way in effect, which is not always the one chosen: with the VPN down a sentence
  // stays here whatever was asked for, and the buttons must not say otherwise.
  readonly property string modeInUse: modelWhere === "cloud" ? "cloud" : modelWhere === "remote" ? "vpn" : modelWhere === "local" ? "local" : mode
  // The three ways, for the buttons that choose between them.
  readonly property var modeOptions: [
    {
      id: "local",
      label: "Local",
      tone: Color.good
    },
    {
      id: "vpn",
      label: "VPN",
      tone: Color.caution,
      available: vpnConfigured && vpnReachable
    },
    {
      id: "cloud",
      label: "Cloud",
      tone: Color.popupUrgent,
      available: cloudKey
    }
  ]
  // What the chosen way comes to when it cannot be had.
  readonly property string modeNote: mode === "cloud" && !cloudKey ? "no key yet: desktop-voice key" : mode === "vpn" && !vpnConfigured ? "no VPN model set up" : mode === "vpn" && !vpnReachable ? "VPN is down, so local until it is back" : mode === "local" && vpnConfigured && vpnReachable ? "VPN is up: click VPN to use its model" : ""

  function setMode(name) {
    root.mode = name;
    Quickshell.execDetached(["desktop-voice", "mode", name]);
  }

  function forget(phrase) {
    Quickshell.execDetached(["desktop-voice", "forget", phrase]);
  }

  // Your own phrases, in an editor; with a phrase, a line is started for it.
  function edit(phrase) {
    Quickshell.execDetached(phrase ? ["desktop-voice", "edit", phrase] : ["desktop-voice", "edit"]);
  }

  property Process stateAsk: Process {
    command: ["desktop-voice", "state"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var s = JSON.parse(text);
          root.mode = String(s.mode || "vpn");
          root.model = String(s.name || "");
          root.modelWhere = String(s.where || "none");
          root.cloudKey = s.cloud_key === true;
          root.vpnConfigured = s.vpn_configured === true;
          root.vpnReachable = s.vpn_reachable === true;
          root.models = s.models || ({});
          root.yours = s.yours || [];
          root.learned = s.learned || [];
          root.missed = s.missed || [];
        } catch (error) {}
      }
    }
  }

  // Not straight from the file's change: several arrive together, and one answer will do.
  property Timer stateSoon: Timer {
    interval: 150
    onTriggered: root.stateAsk.running = true
  }

  property FileView changedFile: FileView {
    path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/desktop/voice/changed"
    printErrors: false
    watchChanges: true
    onFileChanged: root.stateSoon.restart()
  }

  property FileView modelFile: FileView {
    path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/desktop/voice/model"
    printErrors: false
    watchChanges: true
    onFileChanged: root.stateSoon.restart()
  }

  property Timer stateAgain: Timer {
    interval: 60000
    repeat: true
    running: true
    onTriggered: root.stateAsk.running = true
  }

  property Timer giveUp: Timer {
    interval: 45000
    onTriggered: root.state = ""
  }
}
