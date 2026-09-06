import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

import qs.Commons

import "panels"

// One layer-shell panel per monitor, laid out from shell.json's `bar` subtree.
//
// The host owns config file IO; the bar renders whatever it is handed.
Item {
  id: root

  // Injected by shell.qml.
  required property string desktopPath
  required property var widgetRegistry
  required property var barConfig

  // Injected by shell.qml, which owns the runtime flip behind the IPC method.
  property bool transparent: false

  readonly property string position: (barConfig && barConfig.position) ? barConfig.position : "top"
  // Widget id whose centre is pinned to the centre of the screen. Without it the centre
  // section is centred as a block, so the clock slides sideways every time a
  // neighbouring indicator appears or goes away.
  readonly property string centerAnchor: (barConfig && barConfig.centerAnchor) ? barConfig.centerAnchor : ""
  readonly property var layoutConfig: (barConfig && barConfig.layout) ? barConfig.layout : ({
      left: [],
      center: [],
      right: []
    })

  // Hiding parks the bar just past the screen edge rather than unmapping it. Unmapping
  // frees the layer surface and the whole scene graph, so every reveal has to rebuild
  // both; parking keeps the surface alive and makes showing a margin change.
  property bool barHidden: false

  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/desktop"

  // bin/desktop-toggle-bar writes and removes this file. Its absence is the normal
  // case -- it means the bar is shown -- so the read failure is not worth logging.
  FileView {
    path: root.stateDir + "/bar-off"
    printErrors: false
    watchChanges: true
    onLoaded: root.barHidden = true
    onFileChanged: reload()
    onLoadFailed: root.barHidden = false
  }

  // One instance of every panel, shared across monitors. Deliberately outside Variants
  // -- see PopupHost for why one writer matters.
  PopupHost {
    id: popupHost
  }

  // Likewise one tooltip, shared across monitors.
  TooltipHost {
    id: tooltipHost
  }

  // The single instance of each panel. Registered by id so widgets can open one by
  // name without Bar.qml having to expose each panel individually.
  AudioPanel {
    id: audioPanel

    Component.onCompleted: popupHost.register(panelId, this)
    onDismissed: popupHost.notifyClosed(panelId)
  }

  CalendarPanel {
    id: calendarPanel

    Component.onCompleted: popupHost.register(panelId, this)
    onDismissed: popupHost.notifyClosed(panelId)
  }

  NetworkPanel {
    id: networkPanel

    Component.onCompleted: popupHost.register(panelId, this)
    onDismissed: popupHost.notifyClosed(panelId)
  }

  Variants {
    model: Quickshell.screens

    delegate: Component {
      BarPanel {
        required property var modelData

        screen: modelData
      }
    }
  }

  component BarPanel: PanelWindow {
    id: barWindow

    WlrLayershell.namespace: "desktop-bar"
    WlrLayershell.layer: WlrLayer.Top

    // Ignoring the exclusion zone while hidden lets tiled windows reclaim the space.
    exclusionMode: root.barHidden ? ExclusionMode.Ignore : ExclusionMode.Auto

    margins {
      top: root.barHidden && root.position === "top" ? -Style.barSize : 0
      bottom: root.barHidden && root.position === "bottom" ? -Style.barSize : 0
    }

    anchors {
      top: root.position === "top"
      bottom: root.position === "bottom"
      left: true
      right: true
    }

    implicitHeight: Style.barSize
    color: root.transparent ? "transparent" : Color.barBackground

    // Sections are positioned independently so the centre section stays centred on the
    // screen regardless of how wide the left and right sections grow. Anchoring centre
    // between the other two would make the clock drift as the window title changes.
    BarSection {
      id: leftSection

      model: root.layoutConfig.left || []
      barScreen: barWindow.screen
      anchors.left: parent.left
      anchors.leftMargin: Style.sectionSpacing
    }

    BarSection {
      id: centerSection

      model: root.layoutConfig.center || []
      barScreen: barWindow.screen
      anchorId: root.centerAnchor
      // Never negative: a centre section wider than half the bar would otherwise be
      // pushed off the left edge to keep its anchor centred.
      x: Math.max(0, Math.round(parent.width / 2 - anchorOffset))
    }

    BarSection {
      id: rightSection

      model: root.layoutConfig.right || []
      barScreen: barWindow.screen
      anchors.right: parent.right
      anchors.rightMargin: Style.sectionSpacing
    }
  }

  component BarSection: RowLayout {
    id: section

    property var model: []
    // Empty means "centre the whole section", which is the offset of its own middle.
    property string anchorId: ""

    // Distance from the section's left edge to the point that should sit at the centre
    // of the screen. Reads x and width off the anchored loader, so it re-evaluates
    // whenever a widget beside it grows or shrinks.
    readonly property real anchorOffset: {
      if (anchorId !== "") {
        for (var i = 0; i < repeater.count; i++) {
          var loader = repeater.itemAt(i);
          if (loader && loader.modelData && loader.modelData.id === anchorId)
            return loader.x + loader.width / 2;
        }
      }
      return width / 2;
    }
    // Passed down rather than read from an attached property so a widget that needs to
    // know which monitor it is on (workspaces) has it without walking back up the tree.
    property var barScreen: null

    anchors.top: parent.top
    anchors.bottom: parent.bottom
    spacing: Style.itemSpacing

    Repeater {
      id: repeater

      model: section.model

      delegate: Loader {
        required property var modelData

        Layout.fillHeight: true

        // A widget id with no component -- a typo in shell.json, or a widget removed
        // from the registry -- loads nothing rather than breaking the whole section.
        sourceComponent: root.widgetRegistry.componentFor(modelData)

        onLoaded: {
          item.desktopPath = root.desktopPath;
          item.barScreen = section.barScreen;
          item.widgetConfig = modelData;
          item.popups = popupHost;
          item.tooltips = tooltipHost;
        }

        Component.onCompleted: {
          if (!sourceComponent)
            console.warn("Bar: no widget registered for", JSON.stringify(modelData.type || modelData.id));
        }
      }
    }
  }
}
