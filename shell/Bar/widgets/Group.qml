import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

// Bar widgets in one pill, of which only the last few show until it is hovered.
//
//   { "id": "system", "type": "group",
//     "widgets": [{ "id": "disk", "path": "/" }, { "id": "memory" }, { "id": "cpu" }, { "id": "battery" }],
//     "show": ["cpu", "battery"] }
//
// Twenty-odd widgets in one line had no groups for the eye to land on, and on the laptop's
// screen alone they did not fit. In a group they read as one thing -- the connection, the
// sound, the machine -- and the ones that only matter now and then stay out of the way.
//
// At rest the pill shows its widgets from the first one that is listed in "show", or that
// has something to say (`notable`: memory nearly full, the VPN up), to the end. Without a
// "show" every widget is shown and the group is only a pill. Hovered, or while a panel
// opened from one of its widgets is up, it opens leftwards over its neighbours rather than
// pushing them aside: nothing on the bar moves under the pointer.
BarWidget {
  id: root

  // Injected by the bar: the group builds its widgets the way a section does.
  property var registry: null

  readonly property var entries: (widgetConfig && widgetConfig.widgets) || []
  readonly property var shown: (widgetConfig && widgetConfig.show) || null

  readonly property int pad: 4

  // The first widget shown at rest. Read through `notables`, which the widgets' own
  // notable flags feed, so a widget that becomes notable widens the pill on its own.
  property var notables: []
  readonly property int restFrom: {
    if (!shown)
      return 0;
    for (var i = 0; i < entries.length; i++) {
      if (shown.indexOf(entries[i].id) !== -1 || notables[i])
        return i;
    }
    return entries.length;
  }

  function widthFrom(start) {
    var w = 0, n = 0;
    for (var i = start; i < row.children.length; i++) {
      var child = row.children[i];
      if (!child || child.modelData === undefined || !child.visible)
        continue;
      w += child.implicitWidth;
      n++;
    }
    return w + Math.max(0, n - 1) * row.spacing + pad * 2;
  }

  // Recomputed when a widget's width or the rest point moves; widthFrom reads children,
  // which no binding would see change.
  property real restWidth: 0
  property real fullWidth: 0
  function measure() {
    restWidth = restFrom >= entries.length ? 0 : widthFrom(restFrom);
    fullWidth = widthFrom(0);
  }
  onRestFromChanged: Qt.callLater(measure)

  // A panel opened from a widget in here keeps it open, or the widget it hangs from could
  // slide out from under it.
  readonly property bool panelOpen: {
    if (!popups || popups.activeId === "")
      return false;
    for (var i = 0; i < row.children.length; i++) {
      var child = row.children[i];
      if (child && child.item && child.item.panelId === popups.activeId)
        return true;
    }
    return false;
  }
  property bool lingering: false
  readonly property bool open: shown !== null && (hover.hovered || lingering || panelOpen)

  Timer {
    id: linger

    interval: 350
    onTriggered: root.lingering = false
  }

  notable: notables.some(n => n)
  implicitWidth: restWidth
  // No z to put it above its neighbours while open: it opens leftwards, over the ones
  // before it, which a row already draws underneath it. Raising it was tried, and the
  // restacking under a still pointer made Qt take the hover away the moment it opened.

  Rectangle {
    id: capsule

    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    height: Math.round(Style.barSize * 0.74)
    width: root.open ? root.fullWidth : root.restWidth
    radius: height / 2
    color: root.open ? Color.barRaised : Color.barPill
    border.width: 1
    border.color: root.open ? Color.barActiveWorkspace : Color.barOutline
    clip: true
    visible: width > 0

    Behavior on width {
      NumberAnimation {
        duration: Style.motionQuick
        easing.type: Easing.OutCubic
      }
    }
    Behavior on color {
      ColorAnimation {
        duration: Style.motionQuick
      }
    }

    HoverHandler {
      id: hover

      onHoveredChanged: {
        if (hovered) {
          linger.stop();
          root.lingering = false;
        } else {
          root.lingering = true;
          linger.restart();
        }
      }
    }

    RowLayout {
      id: row

      anchors.right: parent.right
      anchors.rightMargin: root.pad
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      spacing: 0

      Repeater {
        model: root.entries

        delegate: Loader {
          id: slot

          required property var modelData
          required property int index

          Layout.fillHeight: true
          sourceComponent: root.registry ? root.registry.componentFor(modelData) : null
          // Hidden ones fade rather than blink as the pill slides over them.
          opacity: root.open || index >= root.restFrom ? 1 : 0
          // A hidden one sits over the neighbours to the left: it must not take their clicks.
          enabled: root.open || index >= root.restFrom

          Behavior on opacity {
            NumberAnimation {
              duration: Style.motionQuick
            }
          }

          onImplicitWidthChanged: Qt.callLater(root.measure)
          onVisibleChanged: Qt.callLater(root.measure)

          function noteNotable() {
            var copy = root.notables.slice();
            copy[index] = !!(item && item.notable);
            root.notables = copy;
          }

          Connections {
            target: slot.item
            ignoreUnknownSignals: true

            function onNotableChanged() {
              slot.noteNotable();
            }
          }

          onLoaded: {
            item.desktopPath = root.desktopPath;
            item.barScreen = root.barScreen;
            item.widgetConfig = modelData;
            item.popups = root.popups;
            item.tooltips = root.tooltips;
            noteNotable();
            Qt.callLater(root.measure);
          }
        }
      }
    }
  }
}
