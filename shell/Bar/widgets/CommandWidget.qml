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
//
// One field waybar does not have: "badge", a short piece drawn after the text as a pill in the
// urgent colour, whatever the class says. The class colours the whole module, and one module can
// have two things to say at once -- the AI module's usage limit going critical and a
// session waiting on you -- where colouring for one would hide the other.
//
// And "gauges", for figures that run out: [{"text": "60%", "level": 0.6}, ...], each drawn
// after the text in its own colour from Color.gauge -- green at 0, red at 1. A class is one
// colour for the whole module, which cannot say that the session is nearly gone while the
// week has barely been touched.
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
  // States in which the module breathes: "pulse": ["waiting", "done"]. For the few that mean
  // something is waiting on you -- colour alone says so only to an eye already on it.
  readonly property var pulse: (widgetConfig && widgetConfig.pulse) ? widgetConfig.pulse : []
  readonly property bool pulsing: state !== "" && pulse.indexOf(state) !== -1

  property string label: ""
  property string badge: ""
  property var gauges: []
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
  visible: !hideWhenEmpty || label !== "" || badge !== "" || gauges.length > 0
  implicitWidth: visible ? content.implicitWidth + Style.itemPaddingH * 2 : 0

  readonly property color textColor: {
    var role = colors[state] || "";
    if (role === "muted")
      return Color.barMuted;
    if (role === "urgent")
      return Color.barUrgent;
    if (role === "accent")
      return Color.barAccent;
    if (role === "good")
      return Color.barGood;
    return Color.barText;
  }

  function apply(output) {
    var trimmed = output.trim();
    if (trimmed === "") {
      label = "";
      badge = "";
      gauges = [];
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
        badge = parsed.badge !== undefined ? String(parsed.badge) : "";
        gauges = Array.isArray(parsed.gauges) ? parsed.gauges : [];
        tooltip = parsed.tooltip !== undefined ? String(parsed.tooltip) : "";
        state = parsed.class !== undefined ? String(parsed.class) : "";
        return;
      } catch (e) {
        console.warn("CommandWidget:", JSON.stringify(root.widgetConfig.id), "printed unparseable JSON:", e);
      }
    }

    label = trimmed.split("\n")[0];
    badge = "";
    gauges = [];
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

  // Asked for over IPC, between two polls. See Bus.widgetRefresh.
  Connections {
    target: Bus

    function onWidgetRefresh(id) {
      if (root.widgetConfig && id === root.widgetConfig.id && root.exec !== "" && !root.follow && !probe.running)
        probe.running = true;
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

  Row {
    id: content

    spacing: 6

    // Down and back up, for as long as the state lasts. Stopping puts it back to full: an
    // animation stopped halfway would leave the module dimmed for no reason anyone could see.
    SequentialAnimation on opacity {
      running: root.pulsing && root.visible
      loops: Animation.Infinite
      alwaysRunToEnd: false
      onRunningChanged: if (!running)
        content.opacity = 1

      NumberAnimation {
        to: 0.35
        duration: Style.motionBreath
        easing.type: Easing.InOutSine
      }
      NumberAnimation {
        to: 1
        duration: Style.motionBreath
        easing.type: Easing.InOutSine
      }
    }

    IconLabel {
      anchors.verticalCenter: parent.verticalCenter
      icon: root.icon
      text: root.label
      color: root.textColor
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      visible: root.label !== "" && root.gauges.length > 0
      text: "·"
      color: Color.barMuted
      font.family: Style.fontFamily
      font.pixelSize: Style.fontSize
    }

    Repeater {
      model: root.gauges

      delegate: Text {
        required property var modelData

        anchors.verticalCenter: parent.verticalCenter
        text: modelData.text !== undefined ? String(modelData.text) : ""
        color: Color.gauge(Number(modelData.level) || 0)
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSize
      }
    }

    // A filled pill rather than coloured text. Coloured text is exactly what disappears when
    // the module is already in the urgent colour -- which is the case the badge is for.
    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      visible: root.badge !== ""
      width: badgeText.implicitWidth + 12
      height: badgeText.implicitHeight + 2
      radius: height / 2
      color: Color.barUrgent

      Text {
        id: badgeText

        anchors.centerIn: parent
        text: root.badge
        color: Color.barBackground
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSize - 1
        font.bold: true
      }
    }
  }
}
