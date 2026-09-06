import QtQuick
import qs.Commons
import qs.Ui

// Clock, ticking once a second like waybar's `interval: 1`.
//
// Left click opens the calendar panel, hover gives the long date, and right click
// opens the timezone picker. Between the first two, waybar's format-alt toggle had
// nothing left to do.
BarItem {
  id: root

  readonly property string format: (widgetConfig && widgetConfig.format) ? widgetConfig.format : "ddd dd HH:mm:ss"
  // The long date waybar's format-alt used to swap in on click. The week number is
  // appended rather than written into the format string: Qt has no week specifier, so
  // a "'W'ww" in a format renders the literal "Www".
  readonly property string altFormat: (widgetConfig && widgetConfig.altFormat) ? widgetConfig.altFormat : "dddd d MMMM yyyy"

  tooltip: Qt.formatDateTime(now, altFormat) + "\nWeek " + Dates.isoWeek(now)

  property date now: new Date()

  rightCommand: ["desktop-launch-floating-terminal-with-presentation", "desktop-tz-select"]
  panelId: "calendar"

  onClicked: if (popups)
    popups.toggle(root.panelId, this)

  Timer {
    interval: 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.now = new Date()
  }

  IconLabel {
    text: Qt.formatDateTime(root.now, root.format)
    color: Color.barText
  }
}
