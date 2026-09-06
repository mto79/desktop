import QtQuick
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Ui

// Default source volume. Hidden unless muted or turned down, so a normal mic does not
// take up bar space -- waybar showed it permanently, which was mostly noise.
BarItem {
  id: root

  readonly property PwNode source: Pipewire.defaultAudioSource
  readonly property bool muted: source && source.audio ? source.audio.muted : false
  readonly property int volume: source && source.audio ? Math.round(source.audio.volume * 100) : 0

  PwObjectTracker {
    objects: root.source ? [root.source] : []
  }

  visible: muted || volume < 100
  implicitWidth: visible ? label.implicitWidth + Style.itemPaddingH * 2 : 0

  tooltip: {
    if (!source)
      return "No input device";
    var name = source.description || source.nickname || source.name;
    return name + "\n" + (muted ? "muted" : volume + "%");
  }

  // Same gestures as the speaker widget: left click opens the audio panel -- which
  // carries the input slider and source list -- and right click toggles mute.
  onClicked: if (popups)
    popups.toggle("audio", this)
  rightCommand: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"]

  function step(delta) {
    if (!source || !source.audio)
      return;
    source.audio.volume = Math.min(1.0, Math.max(0.0, source.audio.volume + delta));
  }

  onScrolledUp: step(0.05)
  onScrolledDown: step(-0.05)

  IconLabel {
    id: label

    icon: ""
    text: root.muted ? "Muted" : root.volume + "%"
    color: root.muted ? Color.barUrgent : Color.barText
  }
}
