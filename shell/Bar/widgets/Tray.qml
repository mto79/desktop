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
BarWidget {
  id: root

  implicitWidth: layout.implicitWidth + (SystemTray.items.values.length > 0 ? Style.itemPaddingH * 2 : 0)

  RowLayout {
    id: layout

    anchors.centerIn: parent
    spacing: 12

    Repeater {
      model: SystemTray.items

      delegate: Item {
        id: trayItem

        required property SystemTrayItem modelData

        implicitWidth: Style.iconSize
        implicitHeight: Style.iconSize

        Image {
          anchors.fill: parent
          source: trayItem.modelData.icon
          sourceSize.width: Style.iconSize
          sourceSize.height: Style.iconSize
          fillMode: Image.PreserveAspectFit
          smooth: true
        }

        MouseArea {
          anchors.fill: parent
          acceptedButtons: Qt.LeftButton | Qt.RightButton

          onClicked: mouse => {
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
