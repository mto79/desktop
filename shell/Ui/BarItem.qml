import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// The wrapper every bar widget sits in: consistent padding, a hover highlight, and
// click handling that shells out to a bin/desktop-* script.
//
// Widgets stay declarative -- they set `command` and never manage a Process of their
// own, which keeps a misbehaving click action from taking the whole bar down.
BarWidget {
  id: root

  default property alias content: contentItem.data

  // Run on left click. A list, as Process expects: ["desktop-menu"] or
  // ["desktop-menu", "power"].
  property var command: null
  // Run on right click.
  property var rightCommand: null
  // Run on scroll up / down.
  property var scrollUpCommand: null
  property var scrollDownCommand: null

  property bool hoverEnabled: true
  property color hoverColor: Color.barHover

  signal clicked
  signal rightClicked
  signal scrolledUp
  signal scrolledDown

  readonly property bool hovered: mouseArea.containsMouse

  // Bar.qml injects `popups` after this component is constructed, so registering in
  // Component.onCompleted would run against a null host and silently do nothing --
  // which is exactly what made the first IPC open answer "unknown".
  function registerAnchor() {
    if (popups && panelId !== "")
      popups.registerAnchor(panelId, root);
  }

  onPopupsChanged: registerAnchor()
  onPanelIdChanged: registerAnchor()

  // Hover in and out is all the host needs; it owns the delay and the single window.
  onHoveredChanged: {
    if (!tooltips)
      return;
    if (hovered)
      tooltips.request(root, root.tooltip);
    else
      tooltips.release(root);
  }

  // Keep the text current while the pointer sits still on a widget whose reading moves.
  onTooltipChanged: if (tooltips && hovered)
    tooltips.request(root, root.tooltip)

  implicitWidth: contentItem.implicitWidth + Style.itemPaddingH * 2

  function run(cmd) {
    if (!cmd || cmd.length === 0)
      return;
    // A fresh Process per invocation: reusing one would drop a click that lands while
    // the previous action is still running.
    runner.createObject(root, {
      command: cmd
    });
  }

  Component {
    id: runner

    Process {
      // Inherit $HOME rather than whatever directory the session manager happened to
      // start the shell in. Some of the things the bar launches resolve paths against
      // the cwd -- wofi's stylesheet ends in `@import ".config/desktop/..."`, which
      // silently loses every theme colour and renders the menu transparent when the
      // cwd is not $HOME.
      workingDirectory: Quickshell.env("HOME")
      running: true
      onExited: destroy()
    }
  }

  Rectangle {
    anchors.fill: parent
    color: root.hoverEnabled && mouseArea.containsMouse ? root.hoverColor : "transparent"
    radius: Style.radius

    Behavior on color {
      ColorAnimation {
        duration: 100
      }
    }
  }

  Item {
    id: contentItem

    anchors.centerIn: parent
    implicitWidth: childrenRect.width
    implicitHeight: childrenRect.height
  }

  MouseArea {
    id: mouseArea

    anchors.fill: parent
    hoverEnabled: root.hoverEnabled
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    onClicked: mouse => {
      if (root.tooltips)
        root.tooltips.release(root);

      if (mouse.button === Qt.RightButton) {
        root.rightClicked();
        root.run(root.rightCommand);
      } else {
        root.clicked();
        root.run(root.command);
      }
    }

    onWheel: wheel => {
      if (wheel.angleDelta.y > 0) {
        root.scrolledUp();
        root.run(root.scrollUpCommand);
      } else if (wheel.angleDelta.y < 0) {
        root.scrolledDown();
        root.run(root.scrollDownCommand);
      }
    }
  }
}
