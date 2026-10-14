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

  // Exposed so shell.qml's IPC handler can open a panel without a click.
  readonly property alias popups: popupHost

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
  AiPanel {
    id: aiPanel

    Component.onCompleted: popupHost.register(panelId, this)
    onDismissed: popupHost.notifyClosed(panelId)
  }

  AudioPanel {
    id: audioPanel

    Component.onCompleted: popupHost.register(panelId, this)
    onDismissed: popupHost.notifyClosed(panelId)
  }

  BackupPanel {
    id: backupPanel

    Component.onCompleted: popupHost.register(panelId, this)
    onDismissed: popupHost.notifyClosed(panelId)
  }

  BatteryPanel {
    id: batteryPanel

    Component.onCompleted: popupHost.register(panelId, this)
    onDismissed: popupHost.notifyClosed(panelId)
  }

  BluetoothPanel {
    id: bluetoothPanel

    Component.onCompleted: popupHost.register(panelId, this)
    onDismissed: popupHost.notifyClosed(panelId)
  }

  CalendarPanel {
    id: calendarPanel

    Component.onCompleted: popupHost.register(panelId, this)
    onDismissed: popupHost.notifyClosed(panelId)
  }

  CapturePanel {
    id: capturePanel

    Component.onCompleted: popupHost.register(panelId, this)
    onDismissed: popupHost.notifyClosed(panelId)
  }

  CpuPanel {
    id: cpuPanel

    Component.onCompleted: popupHost.register(panelId, this)
    onDismissed: popupHost.notifyClosed(panelId)
  }

  TasksPanel {
    id: tasksPanel

    Component.onCompleted: popupHost.register(panelId, this)
    onDismissed: popupHost.notifyClosed(panelId)
  }

  NotificationsPanel {
    id: notificationsPanel

    Component.onCompleted: popupHost.register(panelId, this)
    onDismissed: popupHost.notifyClosed(panelId)
  }

  DictationPanel {
    id: dictationPanel

    Component.onCompleted: popupHost.register(panelId, this)
    onDismissed: popupHost.notifyClosed(panelId)
  }

  MediaPanel {
    id: mediaPanel

    Component.onCompleted: popupHost.register(panelId, this)
    onDismissed: popupHost.notifyClosed(panelId)
  }

  MemoryPanel {
    id: memoryPanel

    Component.onCompleted: popupHost.register(panelId, this)
    onDismissed: popupHost.notifyClosed(panelId)
  }

  MicrophonePanel {
    id: microphonePanel

    Component.onCompleted: popupHost.register(panelId, this)
    onDismissed: popupHost.notifyClosed(panelId)
  }

  MonitorsPanel {
    id: monitorsPanel

    Component.onCompleted: popupHost.register(panelId, this)
    onDismissed: popupHost.notifyClosed(panelId)
  }

  NetworkPanel {
    id: networkPanel

    Component.onCompleted: popupHost.register(panelId, this)
    onDismissed: popupHost.notifyClosed(panelId)
  }

  VpnPanel {
    id: vpnPanel

    Component.onCompleted: popupHost.register(panelId, this)
    onDismissed: popupHost.notifyClosed(panelId)
  }

  RecordingPanel {
    id: recordingPanel

    Component.onCompleted: popupHost.register(panelId, this)
    onDismissed: popupHost.notifyClosed(panelId)
  }

  SecurityPanel {
    id: securityPanel

    Component.onCompleted: popupHost.register(panelId, this)
    onDismissed: popupHost.notifyClosed(panelId)
  }

  StoragePanel {
    id: storagePanel

    Component.onCompleted: popupHost.register(panelId, this)
    onDismissed: popupHost.notifyClosed(panelId)
  }

  UpdatesPanel {
    id: updatesPanel

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

    // Held off the edges it is anchored to by barInset, so that it has corners to round.
    // The compositor adds the anchored edge's margin to the exclusive zone, so windows
    // and panels still start below the bar rather than under its inset.
    margins {
      top: root.position !== "top" ? 0 : (root.barHidden ? -Style.barSize - Style.barInset : Style.barInset)
      bottom: root.position !== "bottom" ? 0 : (root.barHidden ? -Style.barSize - Style.barInset : Style.barInset)
      left: Style.barInset
      right: Style.barInset
    }

    anchors {
      top: root.position === "top"
      bottom: root.position === "bottom"
      left: true
      right: true
    }

    implicitHeight: Style.barSize

    // Read by Popup through its anchor's window. A panel hangs from the bar as one shape
    // with it, which only works while there is a bar drawn to hang from.
    readonly property bool joinsPanels: !root.transparent

    // The window stays transparent and the bar is drawn inside it: a window's own colour
    // fills its whole rectangle, corners and all.
    color: "transparent"

    Rectangle {
      anchors.fill: parent
      radius: Style.radius
      color: root.transparent ? "transparent" : Color.barBackground
    }

    // The centre section is placed first and by nothing but the screen: its anchor -- the
    // clock -- sits on the middle of the bar, always. The other two get what is left on
    // their own side of it, and are the ones that give way when that is not enough.
    //
    // It used to be the other way round: the sides took what they wanted and the centre
    // was clamped clear of the right one, so on the laptop's screen, where the right
    // section is wider than half the bar, the clock sat a hundred pixels left of centre.
    BarSection {
      id: centerSection

      model: root.layoutConfig.center || []
      barScreen: barWindow.screen
      anchorId: root.centerAnchor
      x: Math.round(parent.width / 2 - anchorOffset)
    }

    // Each side lives in a box that ends where the centre begins. The section inside is
    // told the box's width and sheds labels to fit it; the clip is for the case where even
    // that is not enough, so that what cannot fit is cut off rather than painted over the
    // centre, where the widgets underneath would go on claiming clicks nobody could see
    // they owned.
    Item {
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.left: parent.left
      anchors.leftMargin: Style.sectionSpacing
      width: Math.max(0, centerSection.x - Style.sectionSpacing * 2)
      clip: true

      BarSection {
        model: root.layoutConfig.left || []
        barScreen: barWindow.screen
        maxWidth: parent.width
        anchors.left: parent.left
      }
    }

    Item {
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.right: parent.right
      anchors.rightMargin: Style.sectionSpacing
      width: Math.max(0, parent.width - centerSection.x - centerSection.width - Style.sectionSpacing * 2)
      clip: true

      // Anchored right, so what the clip takes is the inner end, next to the centre.
      BarSection {
        model: root.layoutConfig.right || []
        barScreen: barWindow.screen
        maxWidth: parent.width
        anchors.right: parent.right
      }
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
    // The room this section has. Past it, widgets are asked to go compact -- glyph only --
    // starting with whichever gives the most back, so as few as possible lose their text.
    property real maxWidth: Infinity

    // Done by hand rather than as a binding: a widget's width depends on whether it is
    // compact, and whether it is compact depends on the widths. What breaks the circle is
    // that the full width is the same whichever widgets are compact at the moment --
    // current width plus what each compact one is holding back -- so running this again
    // after it has changed something changes nothing.
    function fit() {
      var full = 0;
      var able = [];
      for (var i = 0; i < repeater.count; i++) {
        var loader = repeater.itemAt(i);
        if (!loader)
          continue;
        full += loader.implicitWidth + (i > 0 ? spacing : 0);
        var widget = loader.item;
        if (!widget)
          continue;
        if (widget.compactSaving > 0) {
          able.push(widget);
          if (widget.compact)
            full += widget.compactSaving;
        } else {
          widget.compact = false;
        }
      }
      // Those that would rather keep their text are asked last; among the rest, the one
      // that gives the most back goes first, so as few as possible lose theirs.
      able.sort((a, b) => (a.compactOrder - b.compactOrder) || (b.compactSaving - a.compactSaving));
      for (var j = 0; j < able.length; j++) {
        var over = full > maxWidth;
        if (over)
          full -= able[j].compactSaving;
        able[j].compact = over;
      }
    }

    onMaxWidthChanged: Qt.callLater(fit)

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

        onImplicitWidthChanged: Qt.callLater(section.fit)

        Connections {
          target: item
          ignoreUnknownSignals: true

          function onCompactSavingChanged() {
            Qt.callLater(section.fit);
          }
        }

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
