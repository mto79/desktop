import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons

// Lock, sleep, leave, restart, switch off.
//
// This was a list in the launcher: six lines of text, one of which ends the session and
// one of which switches the machine off, each a single Enter away from the line above it.
// Here they are six tiles across the screen, each with a key of its own, and the three
// that cannot be undone have to be asked for twice -- the first press arms the tile and
// says what the second will do.
//
// What each one does is desktop-power's business, so this and the System menu in
// desktop-menu cannot drift apart.
//
// It also says what switching off would interrupt: how long the machine has been up, and
// whether any coding agent is in the middle of something. That is the thing most worth
// knowing at this moment, and nothing else on the screen puts the two side by side.
Item {
  id: root

  property bool open: false

  // Which tile the keyboard is on, and which one has been pressed once and is waiting to
  // be pressed again. Moving away disarms: a second press has to be for the same thing.
  property int cursor: 0
  property int armed: -1

  // Not until it has been on screen for a moment does a key do anything. It takes the
  // keyboard the instant it opens, and whatever was being typed elsewhere at that instant
  // lands here instead: an "l" or an Enter meant for another window locked the screen the
  // first time this was opened while someone was typing. Keys that arrive before anyone
  // could have read the tiles are swallowed. Escape is not one of them.
  property bool ready: false

  Timer {
    interval: Style.powerKeyDelay
    running: root.open && !root.ready
    onTriggered: root.ready = true
  }

  property string uptime: ""
  property int working: 0
  property int waiting: 0

  readonly property var actions: [
    {
      id: "lock",
      key: "L",
      glyph: "\u{f023}",
      label: "Lock",
      confirm: ""
    },
    {
      id: "screensaver",
      key: "V",
      glyph: "\u{f1104}",
      label: "Screensaver",
      confirm: ""
    },
    {
      id: "suspend",
      key: "S",
      glyph: "\u{f0904}",
      label: "Suspend",
      confirm: ""
    },
    {
      id: "exit",
      key: "X",
      glyph: "\u{f359}",
      label: "Log out",
      confirm: "Press again to end the session"
    },
    {
      id: "reboot",
      key: "R",
      glyph: "\u{f0709}",
      label: "Reboot",
      confirm: "Press again to reboot"
    },
    {
      id: "shutdown",
      key: "P",
      glyph: "\u{f0425}",
      label: "Shut down",
      confirm: "Press again to switch off"
    }
  ]

  function show() {
    cursor = 0;
    armed = -1;
    ready = false;
    uptime = "";
    working = 0;
    waiting = 0;
    open = true;
    uptimeProbe.running = true;
    agentProbe.running = true;
  }

  function hide() {
    open = false;
    armed = -1;
  }

  function toggle() {
    if (open)
      hide();
    else
      show();
    return open;
  }

  function move(delta) {
    cursor = (cursor + delta + actions.length) % actions.length;
    armed = -1;
  }

  function activate(index) {
    if (index < 0 || index >= actions.length)
      return;
    cursor = index;
    var action = actions[index];
    if (action.confirm !== "" && armed !== index) {
      armed = index;
      return;
    }
    hide();
    Quickshell.execDetached(["desktop-power", action.id]);
  }

  readonly property string status: {
    var parts = [];
    if (uptime !== "")
      parts.push(uptime);
    if (waiting > 0)
      parts.push(waiting + (waiting === 1 ? " agent is" : " agents are") + " waiting for you");
    if (working > 0)
      parts.push(working + (working === 1 ? " agent is" : " agents are") + " working");
    return parts.join("  ·  ");
  }

  Process {
    id: uptimeProbe

    command: ["uptime", "-p"]

    stdout: StdioCollector {
      onStreamFinished: root.uptime = text.trim()
    }
  }

  Process {
    id: agentProbe

    command: ["desktop-agent-sessions", "--json"]

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var sessions = JSON.parse(text).sessions || [];
          var busy = 0;
          var held = 0;
          for (var i = 0; i < sessions.length; i++) {
            if (sessions[i].state === "working")
              busy++;
            else if (sessions[i].state === "waiting")
              held++;
          }
          root.working = busy;
          root.waiting = held;
        } catch (error) {
          // No agents to speak of is not worth a warning in the log.
        }
      }
    }
  }

  PanelWindow {
    visible: root.open

    screen: {
      var focused = Hyprland.focusedMonitor;
      for (var i = 0; i < Quickshell.screens.length; i++)
        if (focused && Quickshell.screens[i].name === focused.name)
          return Quickshell.screens[i];
      return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
    }

    WlrLayershell.namespace: "desktop-power"
    WlrLayershell.layer: WlrLayer.Overlay
    // Modal, like the overview: nothing under it should take a key while it is up.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    color: "transparent"

    Rectangle {
      id: backdrop

      anchors.fill: parent
      color: Qt.rgba(Color.popupBackground.r, Color.popupBackground.g, Color.popupBackground.b, Style.overviewDim)
      opacity: root.open ? 1 : 0

      Behavior on opacity {
        enabled: root.open
        NumberAnimation {
          duration: Style.motionEnter
          easing.type: Easing.OutCubic
        }
      }

      MouseArea {
        anchors.fill: parent
        onClicked: root.hide()
      }

      FocusScope {
        id: keys

        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: root.hide()
        Keys.onPressed: event => {
          if (!root.ready) {
            event.accepted = true;
            return;
          }
          if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab || event.key === Qt.Key_Down) {
            root.move(1);
          } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab || event.key === Qt.Key_Up) {
            root.move(-1);
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.activate(root.cursor);
          } else {
            // Each tile's own letter. H and J are left out of the arrows above so that
            // no letter means two things here.
            var typed = event.text.toUpperCase();
            var found = -1;
            for (var i = 0; i < root.actions.length; i++)
              if (typed !== "" && root.actions[i].key === typed)
                found = i;
            if (found === -1)
              return;
            root.activate(found);
          }
          event.accepted = true;
        }
      }

      onVisibleChanged: if (visible)
        keys.forceActiveFocus()

      Column {
        anchors.centerIn: parent
        spacing: Style.overviewSpacing
        scale: root.open ? 1 : 0.97

        Behavior on scale {
          enabled: root.open
          NumberAnimation {
            duration: Style.motionEnter
            easing.type: Easing.OutCubic
          }
        }

        Row {
          id: tiles

          anchors.horizontalCenter: parent.horizontalCenter
          spacing: Style.sectionSpacing * 2

          Repeater {
            model: root.actions

            delegate: Rectangle {
              id: tile

              required property var modelData
              required property int index

              readonly property bool selected: root.cursor === index
              readonly property bool isArmed: root.armed === index
              readonly property color tone: isArmed ? Color.popupUrgent : (selected ? Color.popupAccent : Color.popupText)

              width: Style.powerTileSize
              height: Style.powerTileSize
              radius: Style.radius
              color: selected ? Color.popupHover : Color.popupBackground
              border.width: selected || isArmed ? 2 : 1
              border.color: isArmed ? Color.popupUrgent : (selected ? Color.popupAccent : Color.popupBorder)

              Behavior on color {
                ColorAnimation {
                  duration: Style.motionQuick
                }
              }

              Column {
                anchors.centerIn: parent
                spacing: Style.sectionSpacing

                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: tile.modelData.glyph
                  color: tile.tone
                  font.family: Style.fontFamily
                  font.pixelSize: Style.powerGlyphSize
                }

                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: tile.modelData.label
                  color: tile.tone
                  font.family: Style.fontFamily
                  font.pixelSize: Style.fontSize
                  font.weight: Style.barLabelWeight
                }
              }

              // The key that goes straight to this tile.
              Text {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Style.sectionSpacing
                text: tile.modelData.key
                color: Color.popupMuted
                font.family: Style.fontFamily
                font.pixelSize: Style.fontSize - 2
              }

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                // Hovering moves the selection but must not disarm the tile under the
                // pointer, or a second click could never arrive.
                onEntered: if (root.cursor !== tile.index) {
                  root.cursor = tile.index;
                  root.armed = -1;
                }
                onClicked: root.activate(tile.index)
              }
            }
          }
        }

        // One line under the tiles: what the armed tile will do, or else what switching
        // off would interrupt.
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: root.armed >= 0 ? root.actions[root.armed].confirm : root.status
          color: root.armed >= 0 ? Color.popupUrgent : (root.waiting > 0 ? Color.popupAccent : Color.popupMuted)
          font.family: Style.fontFamily
          font.pixelSize: Style.fontSize
        }
      }
    }
  }
}
