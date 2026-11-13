import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

// Bar widgets in one pill.
//
//   { "id": "system", "type": "group",
//     "widgets": [{ "id": "disk", "path": "/" }, { "id": "memory" }, { "id": "cpu" }, { "id": "battery" }] }
//
// Twenty-odd widgets in one line had no groups for the eye to land on. In a pill they read
// as one thing -- the connection, the sound, the machine. Every widget stays shown and
// nothing changes under the pointer: hiding some until hovered was tried, and was more
// fiddly than it was worth.
//
// Short of room, the bar shortens the widgets inside as it does the ones outside, through
// `compactables` (Bar.qml).
BarWidget {
  id: root

  // Injected by the bar: the group builds its widgets the way a section does.
  property var registry: null

  readonly property var entries: (widgetConfig && widgetConfig.widgets) || []
  readonly property int pad: 4

  // The widgets inside that can give up text, for the bar's fitting. Reassigned rather
  // than mutated, and again when one's saving moves, so the bar hears of it.
  property var compactables: []
  function collect() {
    var out = [];
    for (var i = 0; i < row.children.length; i++) {
      var child = row.children[i];
      if (child && child.item && child.item.compactSaving > 0)
        out.push(child.item);
    }
    compactables = out;
  }

  implicitWidth: row.implicitWidth > 0 ? row.implicitWidth + pad * 2 : 0

  Rectangle {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    height: Math.round(Style.barSize * 0.74)
    radius: height / 2
    color: Color.barPill
    visible: root.implicitWidth > 0
  }

  RowLayout {
    id: row

    anchors.centerIn: parent
    height: parent.height
    spacing: 0

    Repeater {
      model: root.entries

      delegate: Loader {
        id: slot

        required property var modelData

        Layout.fillHeight: true
        sourceComponent: root.registry ? root.registry.componentFor(modelData) : null

        Connections {
          target: slot.item
          ignoreUnknownSignals: true

          function onCompactSavingChanged() {
            Qt.callLater(root.collect);
          }
        }

        onLoaded: {
          item.desktopPath = root.desktopPath;
          item.barScreen = root.barScreen;
          item.widgetConfig = modelData;
          item.popups = root.popups;
          item.tooltips = root.tooltips;
          Qt.callLater(root.collect);
        }
      }
    }
  }
}
