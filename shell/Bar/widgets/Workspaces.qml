import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

// Workspaces for the monitor this panel is on.
//
// Hyprland.workspaces spans every monitor, so it is filtered against the panel's
// screen -- matching waybar's `all-outputs: false`.
BarWidget {
  id: root

  readonly property var monitor: barScreen ? Hyprland.monitorFor(barScreen) : null

  implicitWidth: layout.implicitWidth

  RowLayout {
    id: layout

    anchors.fill: parent
    spacing: Style.itemSpacing

    Repeater {
      model: Hyprland.workspaces

      delegate: Item {
        id: workspace

        required property HyprlandWorkspace modelData

        // A workspace with no monitor yet (just created) is shown rather than hidden:
        // dropping it would make the bar flicker as Hyprland fills the field in.
        readonly property bool onThisMonitor: !root.monitor || !modelData.monitor || modelData.monitor.id === root.monitor.id
        readonly property bool focused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === modelData.id

        visible: onThisMonitor
        Layout.fillHeight: true
        implicitWidth: visible ? label.implicitWidth + Style.itemPaddingH : 0

        Rectangle {
          anchors.fill: parent
          color: hover.containsMouse ? Color.barHover : "transparent"

          Behavior on color {
            ColorAnimation {
              duration: 100
            }
          }
        }

        Text {
          id: label

          anchors.centerIn: parent
          text: workspace.modelData.name
          color: workspace.focused ? Color.barActiveWorkspace : (workspace.modelData.urgent ? Color.barUrgent : Color.barMuted)
          font.family: Style.fontFamily
          font.pixelSize: Style.fontSize
          font.bold: workspace.focused

          Behavior on color {
            ColorAnimation {
              duration: 100
            }
          }
        }

        MouseArea {
          id: hover

          anchors.fill: parent
          hoverEnabled: true
          onClicked: Hyprland.dispatch("workspace " + workspace.modelData.id)
          // Scroll walks workspaces, as it did in waybar.
          onWheel: wheel => Hyprland.dispatch(wheel.angleDelta.y > 0 ? "workspace e-1" : "workspace e+1")
        }
      }
    }
  }
}
