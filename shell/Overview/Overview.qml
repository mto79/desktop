import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons

// Every workspace at once, with what is on it, live.
//
// The bar says which workspaces exist and which one you are on, and nothing about what is
// where: finding a window meant walking the workspaces until it turned up. This lays them
// all out as small screens, each window in its place and showing what it is showing now,
// so the answer is one look. Click a workspace to go there, a window to go to it, or drag
// a window onto another workspace to move it.
//
// The windows are real captures (ScreencopyView on each toplevel), not icons: two
// terminals are told apart by what is in them, and nothing else on the screen says that.
// They are only live while this is open -- the views exist only then.
//
// Geometry comes from Hyprland's own answer for each window (lastIpcObject), which is
// only as fresh as the last time it was asked. So while this is open it is asked again a
// couple of times a second, and the layout is rebuilt when the answer has changed and
// only then: the model is an array, a new one rebuilds every view in it, and rebuilding
// on a timer regardless would make every capture blink.
Item {
  id: root

  property bool open: false

  // What is drawn: one entry per workspace, each with its windows. Rebuilt by snapshot().
  property var cells: []
  property string signature: ""

  // The workspace the keyboard is on, as an index into cells; and the one a dragged
  // window is over, by id.
  property int cursor: 0
  property int dropTarget: 0

  function show() {
    Hyprland.refreshMonitors();
    Hyprland.refreshWorkspaces();
    Hyprland.refreshToplevels();
    signature = "";
    snapshot();
    cursor = 0;
    for (var i = 0; i < cells.length; i++)
      if (cells[i].focused)
        cursor = i;
    dropTarget = 0;
    open = true;
  }

  function hide() {
    open = false;
  }

  function toggle() {
    if (open)
      hide();
    else
      show();
    return open;
  }

  function goTo(workspaceId) {
    hide();
    Hyprland.dispatch("workspace " + workspaceId);
  }

  function focusWindow(address) {
    hide();
    Hyprland.dispatch("focuswindow address:" + address);
  }

  function moveWindow(address, workspaceId) {
    Hyprland.dispatch("movetoworkspacesilent " + workspaceId + ",address:" + address);
    Hyprland.refreshToplevels();
  }

  // Hyprland reports a monitor in the pixels of its mode and a window in the logical ones
  // the layout is done in. The cells are drawn in the second kind.
  function monitorBox(monitor) {
    if (!monitor)
      return null;
    var scale = monitor.scale > 0 ? monitor.scale : 1;
    return {
      x: monitor.x,
      y: monitor.y,
      width: monitor.width / scale,
      height: monitor.height / scale
    };
  }

  function snapshot() {
    var fallback = monitorBox(Hyprland.focusedMonitor) || {
      x: 0,
      y: 0,
      width: 1920,
      height: 1080
    };
    var byId = {};
    var out = [];
    var spaces = Hyprland.workspaces ? Hyprland.workspaces.values : [];
    for (var i = 0; i < spaces.length; i++) {
      var space = spaces[i];
      // Special workspaces -- the scratchpad -- have negative ids and no place in a grid
      // of screens.
      if (space.id <= 0)
        continue;
      var cell = {
        id: space.id,
        name: space.name,
        focused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === space.id,
        box: monitorBox(space.monitor) || fallback,
        windows: []
      };
      byId[space.id] = cell;
      out.push(cell);
    }
    out.sort(function (a, b) {
      return a.id - b.id;
    });

    var sig = [];
    var tops = Hyprland.toplevels ? Hyprland.toplevels.values : [];
    for (var t = 0; t < tops.length; t++) {
      var ipc = tops[t].lastIpcObject;
      if (!ipc || !ipc.at || !ipc.size || !ipc.workspace)
        continue;
      var home = byId[ipc.workspace.id];
      if (!home || ipc.mapped === false || ipc.hidden === true)
        continue;
      home.windows.push({
        toplevel: tops[t],
        address: ipc.address,
        title: ipc.title || "",
        appClass: ipc["class"] || "",
        x: ipc.at[0] - home.box.x,
        y: ipc.at[1] - home.box.y,
        width: ipc.size[0],
        height: ipc.size[1],
        floating: ipc.floating === true,
        recency: ipc.focusHistoryID !== undefined ? ipc.focusHistoryID : 0
      });
      sig.push([ipc.address, ipc.workspace.id, ipc.at[0], ipc.at[1], ipc.size[0], ipc.size[1]].join(","));
    }
    for (var c = 0; c < out.length; c++) {
      // Drawn back to front: tiled under floating, and the most recently used on top.
      out[c].windows.sort(function (a, b) {
        if (a.floating !== b.floating)
          return a.floating ? 1 : -1;
        return b.recency - a.recency;
      });
      sig.push("w" + out[c].id + (out[c].focused ? "*" : ""));
    }

    var next = sig.sort().join("|");
    if (next === signature && cells.length === out.length)
      return;
    signature = next;
    cells = out;
    if (cursor >= cells.length)
      cursor = Math.max(0, cells.length - 1);
  }

  Timer {
    interval: 400
    repeat: true
    running: root.open
    onTriggered: {
      Hyprland.refreshToplevels();
      root.snapshot();
    }
  }

  PanelWindow {
    id: surface

    visible: root.open

    // On the monitor you are looking at.
    screen: {
      var focused = Hyprland.focusedMonitor;
      for (var i = 0; i < Quickshell.screens.length; i++)
        if (focused && Quickshell.screens[i].name === focused.name)
          return Quickshell.screens[i];
      return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
    }

    WlrLayershell.namespace: "desktop-overview"
    WlrLayershell.layer: WlrLayer.Overlay
    // Exclusive on purpose, unlike a panel: this is modal. Nothing under it should take a
    // key or a click while it is up.
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
          // A digit is the workspace of that number, as it is with SUPER held.
          if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
            root.goTo(event.key - Qt.Key_0);
            event.accepted = true;
            return;
          }
          var step = 0;
          if (event.key === Qt.Key_Right || event.key === Qt.Key_L || event.key === Qt.Key_Tab)
            step = 1;
          else if (event.key === Qt.Key_Left || event.key === Qt.Key_H || event.key === Qt.Key_Backtab)
            step = -1;
          else if (event.key === Qt.Key_Down || event.key === Qt.Key_J)
            step = grid.columns;
          else if (event.key === Qt.Key_Up || event.key === Qt.Key_K)
            step = -grid.columns;
          if (step !== 0 && root.cells.length > 0) {
            var next = root.cursor + step;
            if (next >= 0 && next < root.cells.length)
              root.cursor = next;
            event.accepted = true;
            return;
          }
          if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && root.cells.length > 0) {
            root.goTo(root.cells[root.cursor].id);
            event.accepted = true;
          }
        }
      }

      onVisibleChanged: if (visible)
        keys.forceActiveFocus()

      Grid {
        id: grid

        // As close to the shape of the screen as the count allows, so the cells are as
        // large as they can be: five workspaces are three and two, not five in a row.
        readonly property int count: Math.max(1, root.cells.length)
        columns: Math.max(1, Math.ceil(Math.sqrt(count * 1.4)))
        readonly property int rowCount: Math.ceil(count / columns)

        // Every cell is as wide as the widest monitor's would be, and each keeps the
        // shape of its own monitor.
        readonly property real cellWidth: {
          var availW = backdrop.width - Style.overviewMargin * 2 - Style.overviewSpacing * (columns - 1);
          var availH = backdrop.height - Style.overviewMargin * 2 - Style.overviewSpacing * (rowCount - 1);
          var widest = availW / columns;
          var ratio = 0.625;
          for (var i = 0; i < root.cells.length; i++)
            ratio = Math.max(ratio, root.cells[i].box.height / root.cells[i].box.width);
          var tallest = (availH / rowCount - Style.overviewLabelHeight) / ratio;
          return Math.max(80, Math.floor(Math.min(widest, tallest)));
        }

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

        Repeater {
          model: root.cells

          delegate: Item {
            id: cell

            required property var modelData
            required property int index

            // Read by the drop: the workspace under the pointer is found by asking the
            // grid which of these is there.
            readonly property int workspaceId: modelData.id
            readonly property real factor: grid.cellWidth / modelData.box.width
            readonly property bool selected: root.cursor === index
            readonly property bool dropping: root.dropTarget === modelData.id

            width: grid.cellWidth
            height: Style.overviewLabelHeight + Math.round(modelData.box.height * factor)
            // The cell a window is being dragged out of has to draw over its neighbours.
            z: dragged ? 2 : 0
            property bool dragged: false

            Text {
              id: label

              height: Style.overviewLabelHeight
              verticalAlignment: Text.AlignVCenter
              leftPadding: Style.itemPaddingH
              text: cell.modelData.name
              color: cell.modelData.focused ? Color.popupAccent : Color.popupText
              font.family: Style.fontFamily
              font.pixelSize: Style.barLabelSize
              font.weight: Style.barLabelWeight
            }

            Rectangle {
              id: screenArea

              anchors.top: label.bottom
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.bottom: parent.bottom
              radius: Style.radius
              color: cellHover.containsMouse || cell.dropping ? Color.popupHover : Color.popupBackground
              border.width: cell.selected || cell.dropping ? 2 : 1
              border.color: cell.dropping || cell.selected ? Color.popupAccent : Color.popupBorder

              Behavior on color {
                ColorAnimation {
                  duration: Style.motionQuick
                }
              }

              MouseArea {
                id: cellHover

                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.goTo(cell.modelData.id)
              }

              Repeater {
                model: cell.modelData.windows

                delegate: Item {
                  id: win

                  required property var modelData

                  readonly property real homeX: Math.round(modelData.x * cell.factor)
                  readonly property real homeY: Math.round(modelData.y * cell.factor)

                  x: homeX
                  y: homeY
                  width: Math.max(8, Math.round(modelData.width * cell.factor))
                  height: Math.max(8, Math.round(modelData.height * cell.factor))
                  z: grab.drag.active ? 10 : 0

                  // What the window is showing, when the compositor will hand it over.
                  // Under it, a plain card with the title: a window that cannot be
                  // captured, or has not drawn yet, is still a window that is there.
                  Rectangle {
                    anchors.fill: parent
                    radius: Style.barRadius
                    color: Color.popupBackground
                    border.width: 1
                    border.color: grab.containsMouse ? Color.popupAccent : Color.popupBorder

                    Text {
                      anchors.fill: parent
                      anchors.margins: Style.itemPaddingH
                      visible: !view.hasContent
                      text: win.modelData.appClass !== "" ? win.modelData.appClass : win.modelData.title
                      color: Color.popupMuted
                      font.family: Style.fontFamily
                      font.pixelSize: Style.fontSize - 2
                      elide: Text.ElideRight
                      horizontalAlignment: Text.AlignHCenter
                      verticalAlignment: Text.AlignVCenter
                    }
                  }

                  ScreencopyView {
                    id: view

                    anchors.fill: parent
                    anchors.margins: 1
                    captureSource: root.open ? win.modelData.toplevel.wayland : null
                    live: root.open
                  }

                  Rectangle {
                    anchors.fill: parent
                    radius: Style.barRadius
                    color: "transparent"
                    border.width: grab.containsMouse || grab.drag.active ? 2 : 0
                    border.color: Color.popupAccent
                  }

                  MouseArea {
                    id: grab

                    anchors.fill: parent
                    hoverEnabled: true
                    drag.target: win
                    drag.threshold: 6

                    function workspaceUnder(mouse) {
                      var point = mapToItem(grid, mouse.x, mouse.y);
                      var under = grid.childAt(point.x, point.y);
                      return (under && under.workspaceId !== undefined) ? under.workspaceId : 0;
                    }

                    onPressed: cell.dragged = true
                    onPositionChanged: mouse => {
                      if (drag.active)
                        root.dropTarget = workspaceUnder(mouse);
                    }
                    onReleased: mouse => {
                      var wasDragging = drag.active;
                      var target = wasDragging ? workspaceUnder(mouse) : 0;
                      cell.dragged = false;
                      root.dropTarget = 0;
                      if (!wasDragging) {
                        root.focusWindow(win.modelData.address);
                        return;
                      }
                      // Back where it was either way: if it moved, the next snapshot
                      // draws it in its new workspace, and if not, this is where it is.
                      win.x = Qt.binding(function () {
                        return win.homeX;
                      });
                      win.y = Qt.binding(function () {
                        return win.homeY;
                      });
                      if (target > 0 && target !== cell.modelData.id)
                        root.moveWindow(win.modelData.address, target);
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
