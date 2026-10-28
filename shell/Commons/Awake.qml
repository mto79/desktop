pragma Singleton

import QtQuick
import Quickshell

// Whether the screen should stay on however long nobody touches the keyboard.
//
// hypridle starts the screensaver at 15 minutes, locks at 17.5 and turns the screen off
// at 18, and a call is the one time that is wrong without anyone being at fault: you
// are listening, or showing your screen, and not typing. A browser holds the screen
// awake for a video it plays fullscreen, never for a call in a tab. So the shell holds
// it while a microphone is recording or the screen is shared, and for as long as you
// ask it to. Each bar carries an IdleInhibitor bound to `active`; hypridle honours it
// and simply does not count the time.
Singleton {
  id: root

  // Held by hand, from the bar or desktop-toggle-idle. Not kept across a restart of the
  // shell: a hold that outlived the reason for it would leave the machine unlocked.
  property bool held: false

  readonly property bool call: Sound.recording
  readonly property bool sharing: Sharing.active
  readonly property bool active: held || call || sharing

  // What the bar says when asked.
  readonly property string reason: {
    var why = [];
    if (sharing)
      why.push("the screen is shared");
    if (call)
      why.push("a microphone is recording");
    if (held)
      why.push("you asked");
    return why.join(", ");
  }
}
