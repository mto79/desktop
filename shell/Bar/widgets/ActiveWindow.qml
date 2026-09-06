import QtQuick
import Quickshell.Wayland
import qs.Commons
import qs.Ui

// Title of the focused window.
//
// ToplevelManager rather than Hyprland: this is plain wlr-foreign-toplevel, so the
// widget does not care which compositor is underneath. Falls back to the app id for
// windows that never set a title. The manager populates asynchronously, so the title
// is empty for the first moment after the shell starts.
BarItem {
  id: root

  readonly property var toplevel: ToplevelManager.activeToplevel
  readonly property string title: toplevel ? (toplevel.title || toplevel.appId || "") : ""
  readonly property int maxWidth: (widgetConfig && widgetConfig.maxWidth) ? widgetConfig.maxWidth : 280

  visible: title !== ""
  hoverEnabled: false

  // Measured off-tree. The label is given an explicit width so it can elide, and
  // BarItem sizes its content slot from that width -- so measuring the label itself
  // would make the width depend on the width it is meant to produce.
  TextMetrics {
    id: metrics

    font.family: Style.fontFamily
    font.pixelSize: Style.fontSize
    text: root.title
  }

  implicitWidth: visible ? Math.min(maxWidth, metrics.width) + Style.itemPaddingH * 2 : 0

  // Without this the bar snaps a section wider every time focus moves.
  Behavior on implicitWidth {
    NumberAnimation {
      duration: 180
      easing.type: Easing.OutCubic
    }
  }

  Text {
    width: Math.min(root.maxWidth, metrics.width)
    text: root.title
    textFormat: Text.PlainText
    color: Color.barMuted
    font.family: Style.fontFamily
    font.pixelSize: Style.fontSize
    elide: Text.ElideRight
  }
}
