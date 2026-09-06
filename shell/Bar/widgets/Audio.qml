import QtQuick
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Ui

// Default sink volume. Scroll adjusts in 5% steps, matching waybar's scroll-step.
BarItem {
  id: root

  readonly property PwNode sink: Pipewire.defaultAudioSink
  readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
  readonly property int volume: sink && sink.audio ? Math.round(sink.audio.volume * 100) : 0

  readonly property var icons: ["", "", "", ""]
  readonly property string icon: {
    if (muted)
      return "󰝟";
    var index = Math.min(icons.length - 1, Math.max(0, Math.floor(volume / 34)));
    return icons[index];
  }

  // Without this the node's volume properties stay unbound and always read zero.
  PwObjectTracker {
    objects: root.sink ? [root.sink] : []
  }

  tooltip: {
    if (!sink)
      return "No output device";
    var name = sink.description || sink.nickname || sink.name;
    return name + "\n" + (muted ? "muted" : volume + "%");
  }

  // Left click opens the panel; right click keeps toggling mute, which is the gesture
  // that existed before panels and is used far more often than the TUI. wiremix moved
  // to a row inside the panel.
  onClicked: if (popups)
    popups.toggle("audio", this)
  rightCommand: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]

  function step(delta) {
    if (!sink || !sink.audio)
      return;
    sink.audio.volume = Math.min(1.0, Math.max(0.0, sink.audio.volume + delta));
  }

  onScrolledUp: step(0.05)
  onScrolledDown: step(-0.05)

  IconLabel {
    icon: root.icon
    text: root.muted ? "" : root.volume + "%"
    color: root.muted ? Color.barMuted : Color.barText
  }
}
