import QtQuick
import qs.Commons

// Base for everything the bar loads.
//
// Bar.qml injects these three on every widget it creates, so each one declares them
// once here rather than repeating the contract.
Item {
  id: root

  // Root of this checkout, from DESKTOP_PATH. Widgets that shell out to a script in
  // default/ resolve it through this instead of hard-coding a home directory.
  property string desktopPath: ""
  // The screen this widget's panel is on.
  property var barScreen: null
  // This widget's entry from shell.json's layout array, so per-widget options
  // (a clock format, say) travel with the layout.
  property var widgetConfig: ({})
  // The shared PopupHost, for widgets that open a panel: popups.toggle("audio", this).
  property var popups: null
  // The shared TooltipHost. BarItem drives it from hover; a widget only supplies text.
  property var tooltips: null
  // Shown on hover after a short delay. Empty means no tooltip, which is the default:
  // a tooltip that repeats what the label already says is noise.
  property string tooltip: ""

  implicitHeight: parent ? parent.height : Style.barSize
}
