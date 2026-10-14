pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The network scan and the Bluetooth scan, once for the whole shell: the network panel
// and the dashboard start the same scan and show the same answer, and a scan already
// running is not started again from the other one.
//
// Nothing here runs by itself. A scan is a button press -- or a voice command, through
// desktop-shell -- and what was found last is read back from desktop-netscan last and
// desktop-btscan last when the shell starts, so a restart does not forget it.
Singleton {
  id: root

  property var network: null
  property var bluetooth: null
  readonly property bool scanningNetwork: netProc.running
  readonly property bool scanningBluetooth: btProc.running

  // sweep: ping every address even on a network that is not marked as yours.
  function scanNetwork(sweep) {
    if (netProc.running)
      return false;
    netProc.command = sweep ? ["desktop-netscan", "scan", "--sweep"] : ["desktop-netscan", "scan"];
    netProc.running = true;
    return true;
  }

  function scanBluetooth() {
    if (btProc.running)
      return false;
    btProc.running = true;
    return true;
  }

  function parse(text) {
    try {
      var value = JSON.parse(text);
      return value && value.checked ? value : null;
    } catch (e) {
      return null;
    }
  }

  Process {
    id: netProc

    stdout: StdioCollector {
      onStreamFinished: {
        var value = root.parse(text);
        if (value)
          root.network = value;
      }
    }
  }

  Process {
    id: btProc

    command: ["desktop-btscan", "scan", "12"]
    stdout: StdioCollector {
      onStreamFinished: {
        var value = root.parse(text);
        if (value)
          root.bluetooth = value;
      }
    }
  }

  Process {
    running: true
    command: ["desktop-netscan", "last"]
    stdout: StdioCollector {
      onStreamFinished: if (!root.network)
        root.network = root.parse(text)
    }
  }

  Process {
    running: true
    command: ["desktop-btscan", "last"]
    stdout: StdioCollector {
      onStreamFinished: if (!root.bluetooth)
        root.bluetooth = root.parse(text)
    }
  }
}
