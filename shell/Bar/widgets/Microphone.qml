import QtQuick
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Ui

// Default source volume. A microphone at full volume and not muted is the unremarkable
// case, so it is the icon alone, dimmed: waybar showed "100%" permanently, which was mostly
// noise. The number appears when it is turned down, and "Muted" when it is muted.
//
// It used to be hidden altogether in that case. Plugging in a USB microphone, which
// arrives at 100%, then made the icon vanish at the moment it was looked for -- and with
// it the only thing on the bar to click for the microphone panel.
BarItem {
  id: root

  readonly property PwNode source: Pipewire.defaultAudioSource
  readonly property bool muted: source && source.audio ? source.audio.muted : false
  readonly property int volume: source && source.audio ? Math.round(source.audio.volume * 100) : 0

  PwObjectTracker {
    objects: root.source ? [root.source] : []
  }

  readonly property bool unremarkable: !muted && volume >= 100
  visible: source !== null
  implicitWidth: visible ? label.implicitWidth + Style.itemPaddingH * 2 : 0

  tooltip: {
    if (!source)
      return "No input device";
    var name = source.description || source.nickname || source.name;
    return name + "\n" + (muted ? "muted" : volume + "%");
  }

  // Same gestures as the speaker widget: left click opens the microphone panel, right
  // click toggles mute.
  panelId: "microphone"

  onClicked: if (popups)
    popups.toggle(root.panelId, this)
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
    text: root.muted ? "Muted" : (root.unremarkable ? "" : root.volume + "%")
    color: root.muted ? Color.barUrgent : (root.unremarkable ? Color.barMuted : Color.barText)
  }
}
