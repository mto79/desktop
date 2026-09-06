import QtQuick
import qs.Commons
import qs.Ui

// The  button that opens bin/desktop-menu. Static glyph, one click action.
BarItem {
  id: root

  property string desktopPath: ""
  property var widgetConfig: ({})

  command: ["desktop-menu"]

  IconLabel {
    icon: ""
    color: Color.barText
  }
}
