import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

// Monitors panel: where the screens are, which layout put them there, and the others
// that could be applied with what is plugged in right now.
//
// Same shape as the battery panel -- the state big at the top, a picker below -- with a
// map instead of a gauge: the screens drawn to scale where Hyprland has them, rotation
// included, so "home" means the portrait screen on the left without having to know it.
//
// Layouts live in desktop-cmd-monitors-switch, which this panel only asks and tells:
// --list for the ones whose screens are attached, --current for the one in force. Apply
// goes through the same script, which writes the generated file, reloads and re-pins the
// workspaces. Nothing here writes monitor config of its own.
Popup {
  id: root

  readonly property string panelId: "monitors"

  property var monitors: []
  property var layouts: []
  property string current: ""
  property string applying: ""

  // Keyboard: arrows move through the layouts, Enter applies. Unlike the power profile,
  // a layout is not applied as the cursor passes over it -- each one reloads Hyprland.
  property int cursor: -1

  readonly property var choices: layouts.concat(["auto"])
  readonly property var active: monitors.filter(function (m) {
    return !m.disabled;
  })

  readonly property var layoutIcons: ({
      "work": "󰃖",
      "home": "󰋜",
      "laptop": "󰌢",
      "auto": "󰁨"
    })

  function title(name) {
    return name.charAt(0).toUpperCase() + name.slice(1);
  }

  // Hyprland lays screens out in logical pixels: the mode divided by the scale, turned
  // on its side by an odd transform.
  function logical(m) {
    var w = m.width / (m.scale || 1);
    var h = m.height / (m.scale || 1);
    return m.transform % 2 === 1 ? {
      w: h,
      h: w
    } : {
      w: w,
      h: h
    };
  }

  // The model is what a person recognises; the built-in panel's model is a hex id, so it
  // is called what it is.
  function screenName(m) {
    if (m.name.indexOf("eDP") === 0)
      return "Built-in display";
    return m.model && m.model.indexOf("0x") !== 0 ? m.model : m.description;
  }

  function modeText(m) {
    var parts = [m.width + "×" + m.height, Math.round(m.refreshRate) + " Hz"];
    if (m.scale !== 1)
      parts.push("×" + m.scale);
    if (m.transform % 2 === 1)
      parts.push("portrait");
    return parts.join("  ·  ");
  }

  Process {
    id: monitorProbe

    command: ["hyprctl", "monitors", "all", "-j"]

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var list = JSON.parse(text);
          // Left to right, then top to bottom: the order the map reads in.
          list.sort(function (a, b) {
            return a.x - b.x || a.y - b.y;
          });
          root.monitors = list;
        } catch (e) {}
      }
    }
  }

  Process {
    id: layoutProbe

    command: ["bash", "-c", "desktop-cmd-monitors-switch --list; echo; desktop-cmd-monitors-switch --current"]

    stdout: StdioCollector {
      onStreamFinished: {
        var parts = text.split("\n\n");
        root.layouts = (parts[0] || "").split("\n").filter(function (s) {
          return s !== "";
        });
        root.current = parts.length > 1 ? parts[1].trim() : "";
      }
    }
  }

  Process {
    id: applier

    onExited: {
      root.applying = "";
      root.refresh();
    }
  }

  function apply(name) {
    if (applier.running)
      return;
    applying = name;
    applier.command = name === "auto" ? ["desktop-cmd-monitors-switch"] : ["desktop-cmd-monitors-switch", name];
    applier.running = true;
  }

  function refresh() {
    if (!monitorProbe.running)
      monitorProbe.running = true;
    if (!layoutProbe.running)
      layoutProbe.running = true;
  }

  // A screen plugged in or out while the panel is open changes both the map and which
  // layouts are on offer.
  Connections {
    target: Hyprland

    function onRawEvent(event) {
      if (root.visible && (event.name === "monitoraddedv2" || event.name === "monitorremovedv2" || event.name === "configreloaded"))
        root.refresh();
    }
  }

  onVisibleChanged: {
    if (visible) {
      refresh();
      cursor = -1;
    }
  }

  onKeyPressed: event => {
    var count = root.choices.length;
    if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
      var step = event.key === Qt.Key_Left ? -1 : 1;
      if (root.cursor < 0)
        root.cursor = Math.max(0, root.choices.indexOf(root.current));
      else
        root.cursor = Math.max(0, Math.min(count - 1, root.cursor + step));
      event.accepted = true;
    } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && root.cursor >= 0) {
      root.apply(root.choices[root.cursor]);
      event.accepted = true;
    }
  }

  contentWidth: Style.popupWidth
  contentHeight: column.implicitHeight + Style.popupPadding * 2

  Column {
    id: column

    width: parent.width
    spacing: 2

    // --- Which layout, and how many screens --------------------------------------------
    PanelHero {
      icon: root.layoutIcons[root.current] || "󰍹"
      title: "Displays"
      status: {
        if (root.applying !== "")
          return "APPLYING " + root.applying + "...";
        return root.current !== "" ? root.current + " LAYOUT" : "NO LAYOUT APPLIED";
      }
      statusColor: root.applying !== "" ? Color.popupAccent : (root.current !== "" ? Color.popupMuted : Color.popupUrgent)
      value: String(root.active.length)
    }

    // --- The screens as Hyprland places them ------------------------------------------
    Item {
      id: map

      width: parent.width
      height: 128

      readonly property real pad: 8
      readonly property var bounds: {
        var b = {
          x0: Infinity,
          y0: Infinity,
          x1: -Infinity,
          y1: -Infinity
        };
        for (var i = 0; i < root.active.length; i++) {
          var m = root.active[i];
          var size = root.logical(m);
          b.x0 = Math.min(b.x0, m.x);
          b.y0 = Math.min(b.y0, m.y);
          b.x1 = Math.max(b.x1, m.x + size.w);
          b.y1 = Math.max(b.y1, m.y + size.h);
        }
        return b;
      }
      readonly property real factor: root.active.length === 0 ? 0 : Math.min((width - pad * 2) / (bounds.x1 - bounds.x0), (height - pad * 2) / (bounds.y1 - bounds.y0))
      // Centred: the drawing is rarely the shape of the box it sits in.
      readonly property real offsetX: (width - (bounds.x1 - bounds.x0) * factor) / 2
      readonly property real offsetY: (height - (bounds.y1 - bounds.y0) * factor) / 2

      Repeater {
        model: root.active

        delegate: Rectangle {
          id: screen

          required property var modelData

          readonly property var size: root.logical(modelData)

          x: map.offsetX + (modelData.x - map.bounds.x0) * map.factor + 2
          y: map.offsetY + (modelData.y - map.bounds.y0) * map.factor + 2
          width: size.w * map.factor - 4
          height: size.h * map.factor - 4
          radius: 4
          color: modelData.focused ? Color.popupSelected : Color.popupHover
          border.width: 1
          border.color: modelData.focused ? Color.popupAccent : Color.popupBorder

          Column {
            anchors.centerIn: parent
            width: parent.width - 8
            spacing: 1

            Text {
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
              text: screen.modelData.name
              color: screen.modelData.focused ? Color.popupAccent : Color.popupText
              font.family: Style.fontFamily
              font.pixelSize: Style.fontSize - 2
              font.bold: true
              elide: Text.ElideRight
            }

            Text {
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
              visible: screen.height > 34
              text: root.screenName(screen.modelData)
              color: Color.popupMuted
              font.family: Style.fontFamily
              font.pixelSize: Style.fontSize - 4
              elide: Text.ElideRight
            }
          }
        }
      }
    }

    // --- Layouts ----------------------------------------------------------------------
    PanelSection {
      title: "Layout"
      value: "← →  enter"
      rule: true
    }

    Row {
      id: layoutRow

      width: parent.width
      spacing: 6
      leftPadding: 6
      rightPadding: 6
      topPadding: 2

      readonly property real cellWidth: (width - leftPadding - rightPadding - spacing * (root.choices.length - 1)) / Math.max(1, root.choices.length)

      Repeater {
        model: root.choices

        delegate: Rectangle {
          id: cell

          required property string modelData
          required property int index

          readonly property bool isCurrent: root.current === modelData
          readonly property bool isCursor: root.cursor === index

          width: layoutRow.cellWidth
          height: 54
          radius: Style.radius
          color: isCurrent ? Color.popupSelected : (area.containsMouse || isCursor ? Color.popupHover : "transparent")
          border.width: isCursor ? 2 : 1
          border.color: isCurrent || isCursor ? Color.popupAccent : Color.popupBorder
          opacity: root.applying !== "" && root.applying !== modelData ? 0.5 : 1

          Column {
            anchors.centerIn: parent
            spacing: 3

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: root.layoutIcons[cell.modelData] || "󰍹"
              color: cell.isCurrent ? Color.popupAccent : Color.popupText
              font.family: Style.fontFamily
              font.pixelSize: Style.iconSize + 3
            }

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: root.title(cell.modelData)
              color: cell.isCurrent ? Color.popupAccent : Color.popupMuted
              font.family: Style.fontFamily
              font.pixelSize: Style.fontSize - 2
            }
          }

          MouseArea {
            id: area

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            enabled: root.applying === ""
            onClicked: root.apply(cell.modelData)
          }
        }
      }
    }

    // --- Each screen, and what it is running at ---------------------------------------
    PanelSection {
      title: "Screens"
      rule: true
    }

    Repeater {
      model: root.monitors

      delegate: PanelRow {
        required property var modelData

        icon: modelData.name.indexOf("eDP") === 0 ? "󰌢" : "󰍹"
        label: root.screenName(modelData)
        sublabel: modelData.disabled ? modelData.name + "  ·  off in this layout" : modelData.name + "  ·  " + root.modeText(modelData)
        active: modelData.focused
        enabled: false
      }
    }
  }
}
