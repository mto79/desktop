import QtQuick

import "widgets"

// Maps the widget ids used in shell.json to their Components.
//
// An instance, not a singleton: the host injects it into the bar. See the comment in
// shell.qml -- relative-path singleton imports do not share state.
QtObject {
  id: root

  readonly property var components: ({
      "menu": menu,
      "workspaces": workspaces,
      "window": activeWindow,
      "clock": clock,
      "update": systemUpdate,
      "screenrecording": screenRecording,
      "spacer": spacer,
      "tray": tray,
      "bluetooth": bluetooth,
      "media": media,
      "network": network,
      "vpn": vpn,
      "audio": audio,
      "microphone": microphone,
      "disk": disk,
      "memory": memory,
      "cpu": cpu,
      "battery": battery
    })

  // A layout entry names either a built-in widget by id, or a generic module by type:
  //
  //   { "id": "network" }
  //   { "id": "weather", "type": "command", "exec": "desktop-status-weather" }
  //
  // Type wins when both are present, so an entry keeps its own id -- which is what a
  // command module needs to be addressable at all, since several can coexist.
  function componentFor(entry) {
    if (!entry)
      return null;
    if (entry.type && generic[entry.type])
      return generic[entry.type];
    return components[entry.id] || null;
  }

  readonly property var generic: ({
      "command": commandWidget,
      "qml": qmlModule
    })

  property Component commandWidget: Component {
    CommandWidget {}
  }
  property Component qmlModule: Component {
    QmlModule {}
  }

  property Component spacer: Component {
    Spacer {}
  }

  property Component menu: Component {
    DesktopMenu {}
  }
  property Component workspaces: Component {
    Workspaces {}
  }
  property Component activeWindow: Component {
    ActiveWindow {}
  }
  property Component clock: Component {
    Clock {}
  }
  property Component systemUpdate: Component {
    SystemUpdate {}
  }
  property Component screenRecording: Component {
    ScreenRecording {}
  }
  property Component tray: Component {
    Tray {}
  }
  property Component bluetooth: Component {
    Bluetooth {}
  }
  property Component media: Component {
    Media {}
  }
  property Component network: Component {
    Network {}
  }
  property Component vpn: Component {
    Vpn {}
  }
  property Component audio: Component {
    Audio {}
  }
  property Component microphone: Component {
    Microphone {}
  }
  property Component disk: Component {
    Disk {}
  }
  property Component memory: Component {
    Memory {}
  }
  property Component cpu: Component {
    Cpu {}
  }
  property Component battery: Component {
    Battery {}
  }
}
