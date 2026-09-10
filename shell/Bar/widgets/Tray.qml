import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import qs.Commons
import qs.Ui

// StatusNotifier tray icons.
//
// Left click raises the application's window, right click opens the item's own menu.
//
// Raising is done here rather than left to the item's Activate call, because on Wayland
// an application cannot raise itself -- KeePassXC's attempts show up in the journal as
// "Wayland does not support QWindow::requestActivate()", and clicking its tray icon did
// nothing at all. Only the compositor may move focus, so the window is found through the
// foreign-toplevel protocol and activated from here. Activate is still called for items
// with no window of their own, which is the case that call is actually good for.
//
// Each icon is its own hover target, so a tray item behaves like every other thing in
// the bar: it lights up under the pointer, it says what it is, and its highlight is the
// width of the thing you are about to click.
//
// The icons live behind a chevron and unfold on hover, which is what waybar's
// group/tray-expander and Omarchy's bar both do. A tray is the one group in the bar
// worth hiding: its contents are decided by whatever happens to be running, it is four
// anonymous glyphs most of the time, and none of them is a control you go looking for --
// which is the argument Toggles.qml makes for the opposite decision about a cluster of
// two buttons you press on purpose.
//
// One departure from waybar: an item that asks for attention is never folded away. The
// whole point of NeedsAttention is to be seen, and a drawer that swallows it turns the
// tray's only urgent signal into something you find by accident.
BarWidget {
  id: root

  readonly property int iconSize: (widgetConfig && widgetConfig.iconSize) ? widgetConfig.iconSize : Style.trayIconSize

  // {"id": "tray", "fold": false} keeps every icon out, the way this widget used to be.
  readonly property bool foldable: !(widgetConfig && widgetConfig.fold === false)

  readonly property var items: SystemTray.items ? SystemTray.items.values : []

  // Driven by the hover handler through the two timers below, never set directly: a
  // pointer crossing the bar should not be able to open or shut this on its own.
  property bool open: false
  readonly property bool expanded: !foldable || open

  // An item shouting for attention is shown whether the drawer is open or not.
  function pinned(item) {
    return !!item && item.status === Status.NeedsAttention;
  }

  // Recolour icons to the bar's foreground. Off by default and deliberately not
  // automatic: it makes a monochrome icon match the bar and flattens a deliberately
  // coloured one into a silhouette, and only you can say which is which.
  //
  //   {"id": "tray", "tint": true}                  every icon
  //   {"id": "tray", "tint": ["nm-applet", "..."]}  only these, matched on the item id
  readonly property var tintConfig: (widgetConfig && widgetConfig.tint !== undefined) ? widgetConfig.tint : false

  // A glyph from the bar font to fall back to when an item's own icon will not load,
  // keyed on the item id:
  //
  //   {"id": "tray", "glyphs": {"keepassxc": "\uf084", "nm-applet": "\uf1eb"}}
  //
  // A rescue, not a restyle. Two icons on this machine genuinely cannot be resolved --
  // keepassxc-locked, because KeePassXC is an AppImage and only its main icon was copied
  // out, and nm-no-connection-secure -- and both would otherwise be Qt's magenta
  // checkerboard. Everything that does resolve keeps the icon the application shipped,
  // in the colours it shipped it in, because a tray of identical monochrome glyphs is
  // harder to read at a glance than a row of icons you already recognise by shape and
  // colour from every other desktop you have used.
  //
  // This used to force the glyph whether the icon loaded or not, which is why every item
  // in the tray looked alike.
  readonly property var glyphMap: (widgetConfig && widgetConfig.glyphs) ? widgetConfig.glyphs : ({})

  // What an item with no icon and no mapping of its own falls back to. Without it the
  // checkerboard is back the first time some new tray application ships a bad icon name
  // -- which is the whole failure this mechanism exists to prevent, so it should not
  // depend on someone having predicted the offender by name.
  readonly property string fallbackGlyph: (widgetConfig && widgetConfig.fallbackGlyph) ? widgetConfig.fallbackGlyph : "\uf013"

  function glyphFor(item) {
    if (!item)
      return "";
    var id = (item.id || "").toLowerCase();
    for (var key in glyphMap)
      if (String(key).toLowerCase() === id)
        return glyphMap[key];
    return "";
  }

  // A command to run when an item is clicked and has no window to raise, keyed on id:
  //
  //   {"id": "tray", "commands": {"remmina-icon": "remmina"}}
  //
  // Some tray applications simply cannot be reached through the protocol. Remmina runs
  // as `remmina -i` with no window, implements no Activate method, and its menu is an
  // Ayatana one where left-click-opens-the-menu is the intended behaviour -- so the
  // only way to its main window is to run `remmina` again, which the already-running
  // instance answers by showing itself. Explicit configuration rather than guessing at
  // a menu entry called something like "Open Main Window".
  readonly property var commandMap: (widgetConfig && widgetConfig.commands) ? widgetConfig.commands : ({})

  function commandFor(item) {
    if (!item)
      return null;
    var id = (item.id || "").toLowerCase();
    for (var key in commandMap) {
      if (String(key).toLowerCase() !== id)
        continue;
      var value = commandMap[key];
      return Array.isArray(value) ? value : String(value).split(" ");
    }
    return null;
  }

  function shouldTint(item) {
    if (tintConfig === true)
      return true;
    if (!Array.isArray(tintConfig) || !item)
      return false;
    var id = (item.id || "").toLowerCase();
    for (var i = 0; i < tintConfig.length; i++)
      if (String(tintConfig[i]).toLowerCase() === id)
        return true;
    return false;
  }

  // Words too generic to identify anything: every second tray item calls itself an
  // applet or an indicator, and matching on those would focus the wrong window.
  readonly property var noiseWords: ["icon", "applet", "tray", "status", "indicator", "panel", "systray"]

  // Lowercase alphanumeric words of three characters or more. "remmina-icon" gives
  // ["remmina"], which is enough to find "org.remmina.Remmina"; "nm-applet" gives
  // nothing, and correctly falls through to Activate.
  function tokensOf(text) {
    if (!text)
      return [];
    var parts = String(text).toLowerCase().split(/[^a-z0-9]+/);
    var out = [];
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].length < 3)
        continue;
      if (noiseWords.indexOf(parts[i]) !== -1)
        continue;
      out.push(parts[i]);
    }
    return out;
  }

  function flatten(text) {
    return text ? String(text).toLowerCase().replace(/[^a-z0-9]+/g, "") : "";
  }

  // Returns true when a window was found and raised.
  function raiseApplication(item) {
    if (!item)
      return false;

    var tokens = tokensOf(item.id).concat(tokensOf(item.title));
    if (tokens.length === 0)
      return false;

    // Matched against the app id only, never the window title. "nm-applet" reduces to
    // the token "network", and a browser tab called "Network settings" would otherwise
    // be a perfectly good match for it.
    var tops = ToplevelManager.toplevels ? ToplevelManager.toplevels.values : [];
    for (var i = 0; i < tops.length; i++) {
      var haystack = flatten(tops[i].appId);
      for (var t = 0; t < tokens.length; t++) {
        if (haystack.indexOf(tokens[t]) !== -1) {
          tops[i].activate();
          return true;
        }
      }
    }
    return false;
  }

  implicitWidth: layout.implicitWidth
  // Nothing to fold out of, and no chevron worth showing, when the tray is empty.
  visible: items.length > 0

  // A HoverHandler rather than a MouseArea over the group: a MouseArea would have to sit
  // above the per-icon ones to see the pointer, and would then eat the clicks they exist
  // to receive. A handler sees the pointer without competing for it.
  HoverHandler {
    id: groupHover
  }

  onExpandedChanged: if (!expanded && root.tooltips)
    root.tooltips.release(chevron)

  Timer {
    id: openTimer

    interval: Style.trayOpenDelay
    onTriggered: root.open = true
  }

  Timer {
    id: closeTimer

    interval: Style.trayCloseDelay
    onTriggered: root.open = false
  }

  // One writer for both timers, so a pointer that crosses the boundary twice inside a
  // single delay cannot leave the drawer half-committed.
  onHoveredByPointerChanged: {
    openTimer.stop();
    closeTimer.stop();
    if (hoveredByPointer && !root.open)
      openTimer.start();
    else if (!hoveredByPointer && root.open)
      closeTimer.start();
  }

  readonly property bool hoveredByPointer: groupHover.hovered

  RowLayout {
    id: layout

    anchors.centerIn: parent
    // Was a hardcoded 12, which put the tray on a different rhythm from the rest of the
    // bar. The gap only has to keep two hover highlights from touching.
    spacing: Style.itemSpacing

    // The handle. Points the way the icons will go: left while they are folded away,
    // back to the right once they are out.
    Item {
      id: chevron

      visible: root.foldable
      Layout.fillHeight: true
      implicitWidth: root.iconSize + Style.itemPaddingH

      readonly property bool hovered: chevronArea.containsMouse

      onHoveredChanged: if (root.tooltips) {
        if (hovered)
          root.tooltips.request(chevron, root.expanded ? "Hide the tray" : root.items.length + (root.items.length === 1 ? " tray icon" : " tray icons"));
        else
          root.tooltips.release(chevron);
      }

      Rectangle {
        anchors.fill: parent
        color: chevron.hovered ? Color.barHover : "transparent"
        radius: Style.barRadius

        Behavior on color {
          ColorAnimation {
            duration: 100
          }
        }
      }

      Text {
        anchors.centerIn: parent
        text: root.expanded ? "\uf054" : "\uf053"
        color: chevron.hovered ? Color.barText : Color.barMuted
        font.family: Style.fontFamily
        font.pixelSize: Style.iconSize
      }

      // Hover is what opens the drawer; the click is here so that a tray reached by
      // touchpad tap -- which sends no hover -- is not a tray you cannot open.
      MouseArea {
        id: chevronArea

        anchors.fill: parent
        hoverEnabled: true
        onClicked: {
          openTimer.stop();
          closeTimer.stop();
          root.open = !root.open;
        }
      }
    }

    Repeater {
      model: SystemTray.items

      delegate: Item {
        id: trayItem

        required property SystemTrayItem modelData

        readonly property bool tinted: root.shouldTint(modelData)

        // The name inside the provider URL the tray hands us -- "keepassxc-locked" out of
        // "image://icon/keepassxc-locked". Anything after a '?' is the provider's own
        // query, not part of the name.
        readonly property string iconName: {
          var src = String(modelData.icon || "");
          var marker = "image://icon/";
          if (src.indexOf(marker) !== 0)
            return "";
          var name = src.substring(marker.length);
          var query = name.indexOf("?");
          return query === -1 ? name : name.substring(0, query);
        }

        // Image.status is not enough on its own, and this is the trap that made the
        // glyphs an override in the first place. A themed icon the theme cannot resolve
        // does not fail to load: Quickshell's provider answers with Qt's magenta
        // checkerboard at status Ready, so the Image is perfectly happy and the widget
        // has no idea it is drawing a placeholder. Asking whether the name resolves is
        // the only way to find out.
        readonly property bool iconFailed: {
          if (iconImage.status === Image.Error)
            return true;
          if (iconName === "")
            return false;
          return Quickshell.iconPath(iconName, true) === "";
        }
        readonly property string glyph: {
          if (!iconFailed)
            return "";
          var mapped = root.glyphFor(modelData);
          return mapped !== "" ? mapped : root.fallbackGlyph;
        }

        readonly property bool shown: root.expanded || root.pinned(modelData)

        // Half of BarItem's padding either side. The full amount is sized for an icon
        // with a label beside it; a bare icon in it looks marooned.
        readonly property int fullWidth: root.iconSize + Style.itemPaddingH
        implicitWidth: shown ? fullWidth : 0
        implicitHeight: root.height
        // Each icon folds on its own width rather than the row sliding behind a mask:
        // that is what lets a pinned item stay out while the ones beside it close, and
        // it costs nothing -- RowLayout drops a zero-width item and reflows.
        clip: true
        visible: implicitWidth > 0

        Behavior on implicitWidth {
          NumberAnimation {
            duration: Style.trayFoldDuration
            easing.type: Easing.OutCubic
          }
        }

        // A folded icon must not answer the pointer, or the drawer would reopen from
        // under a zero-width sliver the moment it finished closing.
        enabled: shown

        // The same highlight, radius and fade BarItem uses.
        Rectangle {
          anchors.fill: parent
          color: mouseArea.containsMouse ? Color.barHover : "transparent"
          radius: Style.barRadius

          Behavior on color {
            ColorAnimation {
              duration: 100
            }
          }
        }

        Image {
          id: iconImage

          anchors.centerIn: parent
          width: root.iconSize
          height: root.iconSize
          source: trayItem.modelData.icon
          sourceSize.width: root.iconSize
          sourceSize.height: root.iconSize
          fillMode: Image.PreserveAspectFit
          smooth: true
          // Hidden while tinted: the effect below draws it instead. Still a texture
          // provider, which is all MultiEffect needs from it.
          visible: !trayItem.tinted && !trayItem.iconFailed
        }

        MultiEffect {
          anchors.fill: iconImage
          source: iconImage
          visible: trayItem.tinted && !trayItem.iconFailed
          colorization: 1.0
          colorizationColor: Color.barText
        }

        // Rendered exactly as every other bar item's icon is: same font, same size, same
        // colour, so a mapped tray item is indistinguishable from a built-in widget.
        Text {
          anchors.centerIn: parent
          visible: trayItem.glyph !== ""
          text: trayItem.glyph
          color: Color.barText
          font.family: Style.fontFamily
          font.pixelSize: Style.iconSize
        }

        // Every other widget names itself on hover; a tray of four anonymous glyphs was
        // the one place in the bar you had to already know what you were looking at.
        //
        // tooltipTitle first: it is the field the protocol means for this, and it is
        // the more useful of the two where an application sets it -- KeePassXC puts
        // "Passwords.kdbx [Locked]" there and only its own name in title. Most set
        // nothing, hence the fallbacks.
        readonly property string label: {
          if (modelData.tooltipTitle && modelData.tooltipTitle !== "")
            return modelData.tooltipTitle;
          if (modelData.title && modelData.title !== "")
            return modelData.title;
          return modelData.id ? modelData.id : "";
        }

        onLabelChanged: if (root.tooltips && mouseArea.containsMouse)
          root.tooltips.request(trayItem, label)

        MouseArea {
          id: mouseArea

          anchors.fill: parent
          hoverEnabled: true
          acceptedButtons: Qt.LeftButton | Qt.RightButton

          onEntered: if (root.tooltips)
            root.tooltips.request(trayItem, trayItem.label)
          onExited: if (root.tooltips)
            root.tooltips.release(trayItem)

          onClicked: mouse => {
            if (root.tooltips)
              root.tooltips.release(trayItem);

            if (mouse.button === Qt.RightButton || trayItem.modelData.onlyMenu) {
              menuAnchor.open();
              return;
            }

            // Window first, then menu, then Activate.
            //
            // Activate is last because plenty of items do not implement it: remmina
            // runs as `remmina -i` with no window at all and answers the call with "No
            // such method", so a click on it did nothing whatsoever. Its menu is where
            // "Open Main Window" lives, which is the thing you actually wanted. The
            // same holds for nm-applet and fcitx, which are menus with an icon
            // attached and have no window of their own to raise.
            if (root.raiseApplication(trayItem.modelData))
              return;
            // Below raising, above the menu: once the command has produced a window,
            // later clicks take the cheaper path and simply raise it.
            var command = root.commandFor(trayItem.modelData);
            if (command) {
              Quickshell.execDetached(root.launch(command));
              return;
            }
            if (trayItem.modelData.hasMenu) {
              menuAnchor.open();
              return;
            }
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
