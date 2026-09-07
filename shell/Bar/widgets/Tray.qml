import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import qs.Commons
import qs.Ui

// StatusNotifier tray icons.
//
// Left click activates, right click opens the item's own menu. waybar hid these behind
// an expander drawer; they are shown directly here, since the count is normally small.
//
// Each icon is its own hover target rather than the tray being one block, so a tray
// item behaves like every other thing in the bar: it lights up under the pointer, it
// says what it is, and its highlight is the width of the thing you are about to click.
// The icons themselves cannot be restyled -- they arrive from the applications as icon
// names or pixmaps, and are whatever those applications ship.
BarWidget {
  id: root

  readonly property int iconSize: (widgetConfig && widgetConfig.iconSize) ? widgetConfig.iconSize : Style.trayIconSize

  implicitWidth: layout.implicitWidth

  RowLayout {
    id: layout

    anchors.centerIn: parent
    // Was a hardcoded 12, which put the tray on a different rhythm from the rest of the
    // bar. The gap only has to keep two hover highlights from touching.
    spacing: Style.itemSpacing

    Repeater {
      model: SystemTray.items

      delegate: Item {
        id: trayItem

        required property SystemTrayItem modelData

        // Half of BarItem's padding either side. The full amount is sized for an icon
        // with a label beside it; a bare icon in it looks marooned.
        implicitWidth: root.iconSize + Style.itemPaddingH
        implicitHeight: root.height

        // The same highlight, radius and fade BarItem uses, so a tray icon does not
        // acknowledge the pointer differently from its neighbours.
        Rectangle {
          anchors.fill: parent
          color: mouseArea.containsMouse ? Color.barHover : "transparent"
          radius: Style.radius

          Behavior on color {
            ColorAnimation {
              duration: 100
            }
          }
        }

        Image {
          anchors.centerIn: parent
          width: root.iconSize
          height: root.iconSize
          source: trayItem.modelData.icon
          sourceSize.width: root.iconSize
          sourceSize.height: root.iconSize
          fillMode: Image.PreserveAspectFit
          smooth: true
        }

        // Every other widget names itself on hover; a tray of four anonymous glyphs was
        // the one place in the bar you had to already know what you were looking at.
        //
        // tooltipTitle first: it is the field the protocol means for this, and it is
        // the more useful of the two where an application sets it -- KeePassXC puts
        // "Passwords.kdbx [Locked]" there and only its own name in title. Most set
        // nothing, hence the fallbacks.
        readonly property string label: {
          if (modelData.tooltipTitle && modelData.tooltipTitle !== "")
            return modelData.tooltipTitle;
          if (modelData.title && modelData.title !== "")
            return modelData.title;
          return modelData.id ? modelData.id : "";
        }

        onLabelChanged: if (root.tooltips && mouseArea.containsMouse)
          root.tooltips.request(trayItem, label)

        MouseArea {
          id: mouseArea

          anchors.fill: parent
          hoverEnabled: true
          acceptedButtons: Qt.LeftButton | Qt.RightButton

          onEntered: if (root.tooltips)
            root.tooltips.request(trayItem, trayItem.label)
          onExited: if (root.tooltips)
            root.tooltips.release(trayItem)

          onClicked: mouse => {
            // Releasing on click matches BarItem: the menu is about to cover the spot
            // the tooltip would sit in.
            if (root.tooltips)
              root.tooltips.release(trayItem);

            if (mouse.button === Qt.RightButton || trayItem.modelData.onlyMenu)
              menuAnchor.open();
            else
              trayItem.modelData.activate();
          }
        }

        QsMenuAnchor {
          id: menuAnchor

          menu: trayItem.modelData.menu
          anchor.item: trayItem
          anchor.edges: Edges.Bottom
        }
      }
    }
  }
}
