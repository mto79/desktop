import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui

// A bar module defined entirely in shell.json, for the case where a script already
// knows the answer and a whole .qml file would be ceremony:
//
//   { "id": "weather", "type": "command", "exec": "desktop-status-weather",
//     "interval": 900, "onClick": "desktop-launch-browser https://example.com" }
//
// The script may print plain text, or the waybar-style JSON every status script in
// bin/ already emits -- {"text": ..., "tooltip": ..., "class": ...} -- so a module
// written for waybar keeps working here without being rewritten.
BarItem {
  id: root

  // Shell strings, not argv arrays: these come from a config file, where writing
  // "~/bin/thing --flag | head -1" is the whole point. Arrays are accepted too, for a
  // command whose arguments should not go anywhere near word splitting.
  readonly property var exec: (widgetConfig && widgetConfig.exec) ? widgetConfig.exec : ""
  readonly property int interval: (widgetConfig && widgetConfig.interval) ? widgetConfig.interval * 1000 : 5000
  // "follow": true for a script that streams a line per change rather than printing
  // once and exiting -- `voxtype status --follow`, `journalctl -f`, anything with a
  // --follow of its own. Polling such a script would never see it finish.
  readonly property bool follow: !!(widgetConfig && widgetConfig.follow)
  readonly property string icon: (widgetConfig && widgetConfig.icon) ? widgetConfig.icon : ""
  // Class -> colour role, for a script that reports state the way waybar's CSS classes
  // did: { "colors": { "vpn-off": "muted", "critical": "urgent" } }.
  readonly property var colors: (widgetConfig && widgetConfig.colors) ? widgetConfig.colors : ({})
  // A module with nothing to say takes no space, which is what makes this usable for
  // indicators that are absent most of the time.
  readonly property bool hideWhenEmpty: !(widgetConfig && widgetConfig.hideWhenEmpty === false)

  property string label: ""
  property string state: ""

  function shell(value) {
    if (!value)
      return null;
    if (Array.isArray(value))
      return value;
    return ["bash", "-c", value];
  }

  // "panel": "ai" hands the left click to a panel instead of a command. The two are
  // mutually exclusive by construction -- a click cannot both open a popup and launch
  // something -- so onRightClick is where the command goes when a panel takes the left.
  panelId: (widgetConfig && widgetConfig.panel) ? widgetConfig.panel : ""

  onClicked: if (root.panelId !== "" && popups)
    popups.toggle(root.panelId, this)

  command: root.panelId !== "" ? null : shell(widgetConfig ? widgetConfig.onClick : null)
  rightCommand: shell(widgetConfig ? widgetConfig.onRightClick : null)
  scrollUpCommand: shell(widgetConfig ? widgetConfig.onScrollUp : null)
  scrollDownCommand: shell(widgetConfig ? widgetConfig.onScrollDown : null)

  // The icon is decoration for the label, so it does not on its own keep an otherwise
  // empty module on the bar.
  visible: !hideWhenEmpty || label !== ""
  implicitWidth: visible ? content.implicitWidth + Style.itemPaddingH * 2 : 0

  readonly property color textColor: {
    var role = colors[state] || "";
    if (role === "muted")
      return Color.barMuted;
    if (role === "urgent")
      return Color.barUrgent;
    if (role === "accent")
      return Color.barAccent;
    return Color.barText;
  }

  function apply(output) {
    var trimmed = output.trim();
    if (trimmed === "") {
      label = "";
      state = "";
      tooltip = "";
      return;
    }

    // Waybar JSON or plain text. Anything that does not parse as an object is treated
    // as text, so a script that prints a bare number is not a configuration error.
    if (trimmed.charAt(0) === "{") {
      try {
        var parsed = JSON.parse(trimmed);
        label = parsed.text !== undefined ? String(parsed.text) : "";
        tooltip = parsed.tooltip !== undefined ? String(parsed.tooltip) : "";
        state = parsed.class !== undefined ? String(parsed.class) : "";
        return;
      } catch (e) {
        console.warn("CommandWidget:", JSON.stringify(root.widgetConfig.id), "printed unparseable JSON:", e);
      }
    }

    label = trimmed.split("\n")[0];
    state = "";
  }

  // Polled: run, read everything, exit, repeat on the timer.
  Process {
    id: probe

    command: root.shell(root.exec) || []

    stdout: StdioCollector {
      onStreamFinished: root.apply(text)
    }
  }

  Timer {
    interval: root.interval
    running: root.exec !== "" && !root.follow
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!probe.running)
      probe.running = true
  }

  // Followed: stay running and read a line at a time.
  Process {
    id: follower

    command: root.shell(root.exec) || []
    running: root.follow && root.exec !== ""

    stdout: SplitParser {
      onRead: line => root.apply(line)
    }

    // A follower that dies -- the tool it watches restarting, say -- is started again
    // rather than leaving the module frozen on its last reading.
    onExited: if (root.follow)
      restart.start()
  }

  Timer {
    id: restart

    interval: 2000
    onTriggered: if (root.follow && !follower.running)
      follower.running = true
  }

  IconLabel {
    id: content

    icon: root.icon
    text: root.label
    color: root.textColor
  }
}
