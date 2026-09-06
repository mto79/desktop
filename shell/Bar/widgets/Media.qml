import QtQuick
import qs.Commons
import qs.Ui

// What is playing, from MPRIS. Absent entirely when nothing is.
//
// The player itself is chosen by the Media singleton, so this and the panel cannot
// disagree about which one "the" player is.
BarItem {
  id: root

  readonly property var player: Media.active
  readonly property int maxWidth: (widgetConfig && widgetConfig.maxWidth) ? widgetConfig.maxWidth : 240

  panelId: "media"

  visible: Media.available
  implicitWidth: visible ? content.implicitWidth + Style.itemPaddingH * 2 : 0

  // A glyph for identity, not for action -- the transport buttons live in the panel,
  // and a play triangle sitting in the bar reads as one.
  readonly property string icon: ""

  readonly property string label: Media.label(player)

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

  // Elided off-tree rather than by giving the label a width: IconLabel sizes itself
  // from its text, so a width there would make the widget's width depend on the width
  // it is meant to produce. TextMetrics hands back the shortened string instead.
  TextMetrics {
    id: metrics

    font.family: Style.fontFamily
    font.pixelSize: Style.fontSize
    elide: Text.ElideRight
    elideWidth: root.maxWidth
    text: root.label
  }

  IconLabel {
    id: content

    icon: root.icon
    text: metrics.elidedText
    color: (root.player && root.player.isPlaying) ? Color.barText : Color.barMuted
  }
}
