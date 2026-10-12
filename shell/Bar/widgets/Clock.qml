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

  // "pill": true sets the clock on a plate of its own, the way the workspaces are, which
  // is what makes it the middle of the bar rather than one more item in a row: what you
  // switch on sits to its left, what is asking for you to its right.
  readonly property bool pill: !!(widgetConfig && widgetConfig.pill)
  // "seconds": true draws the minute going by as a line along the bottom of the plate.
  // The time is shown to the minute; this is the part of it that moves, without a digit
  // changing every second in the corner of the eye.
  readonly property bool seconds: pill && !!(widgetConfig && widgetConfig.seconds)

  Item {
    implicitWidth: label.implicitWidth + (root.pill ? Style.barWorkspacePaddingH * 2 : 0)
    implicitHeight: root.pill ? Math.max(label.implicitHeight, root.height - Style.barWorkspaceInsetV * 2) : label.implicitHeight

    Rectangle {
      id: plate

      visible: root.pill
      anchors.fill: parent
      radius: Style.barWorkspaceRadius
      color: Color.barWorkspaceBackground

      Rectangle {
        id: passing

        readonly property int second: root.now.getSeconds()

        visible: root.seconds
        anchors.left: parent.left
        anchors.leftMargin: Style.barWorkspacePaddingH
        anchors.bottom: parent.bottom
        height: Style.barWorkspaceIndicatorHeight
        radius: height / 2
        width: Math.round((parent.width - Style.barWorkspacePaddingH * 2) * second / 59)
        color: Color.barActiveWorkspace
        opacity: 0.7

        // It glides from one second to the next, and jumps back at the top of the
        // minute: a line running backwards across the plate would be the one second in
        // sixty that draws the eye.
        Behavior on width {
          enabled: passing.second !== 0

          NumberAnimation {
            duration: 1000
          }
        }
      }
    }

    IconLabel {
      id: label

      anchors.centerIn: parent
      text: Qt.formatDateTime(root.now, root.format)
      color: Color.barText
    }
  }
}
