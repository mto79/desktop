import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// A bar widget written outside this checkout:
//
//   { "id": "gpu", "type": "qml" }
//
// loads ~/.config/desktop/bar/modules/gpu.qml, or whatever "source" names instead. The
// point is a one-off widget that never has to be committed here -- the command module
// covers "a script already knows the answer", this covers "it needs to draw something".
//
// The loaded file is an Item. Anything it declares out of `bar`, `moduleName` and
// `settings` is bound; anything it does not declare is skipped rather than being an
// error, so a module only asks for what it uses. It can also just import qs.Commons
// and qs.Ui directly, since it runs in this shell's engine.
//
// Those three arrive as bindings rather than one-time assignments, so a module reads
// them in its own bindings or in an onChanged handler -- not in Component.onCompleted,
// which runs before the host has anything to give it.
BarItem {
  id: root

  readonly property string moduleName: (widgetConfig && widgetConfig.id) ? widgetConfig.id : ""
  readonly property var settings: widgetConfig ? widgetConfig : ({})

  // One binding, not a path plus a separate guard: widgetConfig arrives after this
  // component is built, and two bindings updating in the same turn gave the Loader a
  // moment where it was enabled but still holding the empty-id path, which it then
  // tried and failed to load.
  readonly property url moduleUrl: {
    var home = Quickshell.env("HOME");
    if (widgetConfig && widgetConfig.source)
      return "file://" + widgetConfig.source.replace("~", home);
    if (moduleName === "")
      return "";
    return "file://" + home + "/.config/desktop/bar/modules/" + moduleName + ".qml";
  }

  // The small surface a module needs so it does not have to reach into the shell's
  // internals: colours, the bar's own geometry, and the two things a widget does --
  // run something, say something on hover.
  readonly property QtObject bar: QtObject {
    readonly property color foreground: Color.barText
    readonly property color background: Color.barBackground
    readonly property color muted: Color.barMuted
    readonly property color accent: Color.barAccent
    readonly property color urgent: Color.barUrgent
    readonly property string fontFamily: Style.fontFamily
    readonly property int fontSize: Style.fontSize
    readonly property int barSize: Style.barSize

    function run(command) {
      root.run(Array.isArray(command) ? command : ["bash", "-c", command]);
    }

    function showTooltip(text) {
      root.tooltip = text;
    }

    function hideTooltip() {
      root.tooltip = "";
    }
  }

  visible: loader.status === Loader.Ready
  implicitWidth: visible ? loader.implicitWidth + Style.itemPaddingH * 2 : 0

  Loader {
    id: loader

    source: root.moduleUrl

    onStatusChanged: if (status === Loader.Error)
      console.warn("QmlModule:", JSON.stringify(root.moduleName), "failed to load", root.moduleUrl)
  }

  // Binding rather than assignment in onLoaded: a property the module did not declare
  // is skipped instead of raising "cannot assign to non-existent property", and an
  // edit to shell.json reaches a module that is already on screen.
  Binding {
    target: loader.item
    property: "bar"
    value: root.bar
    when: loader.item !== null && ("bar" in loader.item)
  }

  Binding {
    target: loader.item
    property: "moduleName"
    value: root.moduleName
    when: loader.item !== null && ("moduleName" in loader.item)
  }

  Binding {
    target: loader.item
    property: "settings"
    value: root.settings
    when: loader.item !== null && ("settings" in loader.item)
  }
}
