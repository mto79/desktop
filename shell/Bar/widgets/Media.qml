import QtQuick
import qs.Commons
import qs.Ui

// That something is playing, from MPRIS. Absent entirely when nothing is.
//
// No title on the bar: it is a long string that changes every few minutes and is read
// almost never. The equalizer says that music is on, the tooltip says what, and the card
// that comes up when a track starts says the rest.
//
// The player itself is chosen by the Media singleton, so this and the panel cannot
// disagree about which one "the" player is.
BarItem {
  id: root

  readonly property var player: Media.active

  panelId: "media"

  visible: Media.available
  implicitWidth: visible ? content.implicitWidth + Style.itemPaddingH * 2 : 0

  // A glyph for identity, not for action -- the transport buttons live in the panel,
  // and a play triangle sitting in the bar reads as one.
  readonly property string icon: ""

  tooltip: {
    if (!player)
      return "";
    var lines = [];
    if (player.trackTitle)
      lines.push(player.trackTitle);
    if (player.trackArtist)
      lines.push(player.trackArtist);
    if (player.trackAlbum)
      lines.push(player.trackAlbum);
    lines.push(player.identity + (player.isPlaying ? " - playing" : " - paused"));
    return lines.join("\n");
  }

  onClicked: if (popups)
    popups.toggle(root.panelId, this)
  // The gesture that gets used twenty times a day should not need a panel.
  onRightClicked: if (player && player.canTogglePlaying)
    player.togglePlaying()

  function step(delta) {
    if (!player || !player.volumeSupported)
      return;
    player.volume = Math.min(1.0, Math.max(0.0, player.volume + delta));
  }

  onScrolledUp: step(0.05)
  onScrolledDown: step(-0.05)

  // Playing, the equalizer takes the glyph's place: it says "sound is coming out" better
  // than a breathing note does. Paused, or with no cava to listen through, the glyph
  // comes back.
  Item {
    id: content

    readonly property bool dancing: !!root.player && root.player.isPlaying && Spectrum.live

    implicitWidth: dancing ? equalizer.implicitWidth : glyph.implicitWidth
    implicitHeight: Style.barSize

    Equalizer {
      id: equalizer

      anchors.verticalCenter: parent.verticalCenter
      visible: content.dancing
      levels: Spectrum.levels
      count: 12
      barWidth: 3
      spacing: 2
      height: Style.barSize - 18
    }

    IconLabel {
      id: glyph

      anchors.verticalCenter: parent.verticalCenter
      visible: !content.dancing
      icon: root.icon
      color: (root.player && root.player.isPlaying) ? Color.barAccent : Color.barMuted
      lively: !!root.player && root.player.isPlaying
    }
  }
}
