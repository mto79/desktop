pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// Whether the screen is being shared: a call, a recording through the portal. Hyprland
// says so on its event socket as "screencast>>1,<owner>" when a share starts and
// "screencast>>0,<owner>" when it stops.
//
// For what should not be on a shared screen without asking: the network details list
// every address and route the VPN reaches, which is a map of a network that is not yours
// to show. A share that began before the shell started is not known about until it ends.
Singleton {
  id: root

  property bool active: false

  Connections {
    target: Hyprland

    function onRawEvent(event) {
      if (event.name === "screencast")
        root.active = String(event.data).split(",")[0] === "1";
    }
  }
}
