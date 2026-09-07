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
BarWidget {
  id: root

  readonly property int iconSize: (widgetConfig && widgetConfig.iconSize) ? widgetConfig.iconSize : Style.trayIconSize

  // Recolour icons to the bar's foreground. Off by default and deliberately not
  // automatic: it makes a monochrome icon match the bar and flattens a deliberately
  // coloured one into a silhouette, and only you can say which is which.
  //
  //   {"id": "tray", "tint": true}                  every icon
  //   {"id": "tray", "tint": ["nm-applet", "..."]}  only these, matched on the item id
  readonly property var tintConfig: (widgetConfig && widgetConfig.tint !== undefined) ? widgetConfig.tint : false

  // Replace an item's icon with a glyph from the bar font, keyed on the item id:
  //
  //   {"id": "tray", "glyphs": {"keepassxc": "\uf084", "nm-applet": "\uf1eb"}}
  //
  // This is the only way a tray icon can genuinely match the rest of the bar. The icons
  // themselves arrive from the applications as names or pixmaps and cannot be restyled
  // -- Omarchy does not restyle them either, it hides them behind a hover drawer -- so
  // looking like the bar means not using them at all. Anything unmapped keeps its own
  // icon, which is the sane default for a tray whose contents change.
  //
  // It also rescues an icon the theme cannot resolve: keepassxc-locked exists nowhere on
  // this machine, because KeePassXC is an AppImage and only its main icon was copied
  // out, and it would otherwise be Qt's magenta checkerboard.
  readonly property var glyphMap: (widgetConfig && widgetConfig.glyphs) ? widgetConfig.glyphs : ({})

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

  RowLayout {
    id: layout

    anchors.centerIn: parent
    // Was a hardcoded 12, which put the tray on a different rhythm from the rest of the
    // bar. The gap only has to keep two hover highlights from touching.
    spacing: Style.itemSpacing

    Repeater {
      model: SystemTray.items

      delegate: Item {
        id: trayItem

        required property SystemTrayItem modelData

        readonly property bool tinted: root.shouldTint(modelData)
        readonly property string glyph: root.glyphFor(modelData)

        // Half of BarItem's padding either side. The full amount is sized for an icon
        // with a label beside it; a bare icon in it looks marooned.
        implicitWidth: root.iconSize + Style.itemPaddingH
        implicitHeight: root.height

        // The same highlight, radius and fade BarItem uses.
        Rectangle {
          anchors.fill: parent
          color: mouseArea.containsMouse ? Color.barHover : "transparent"
          radius: Style.radius

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
          visible: !trayItem.tinted && trayItem.glyph === ""
        }

        MultiEffect {
          anchors.fill: iconImage
          source: iconImage
          visible: trayItem.tinted && trayItem.glyph === ""
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
