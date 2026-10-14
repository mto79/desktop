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

  // Measured separately from the label because, while the equalizer stands in for the
  // glyph, going compact empties the label's text -- and what compact gives back has to
  // stay the same whether it is compact or not, or the bar's fitting never settles.
  TextMetrics {
    id: shown

    font.family: Style.fontFamily
    font.pixelSize: Style.fontSize
    text: metrics.elidedText
  }

  // Playing, the equalizer takes the glyph's place: it says "sound is coming out" better
  // than a breathing note does. Paused, or with no cava to listen through, the glyph
  // comes back.
  Row {
    id: content

    readonly property bool dancing: !!root.player && root.player.isPlaying && Spectrum.live

    // BarItem hands `compact` to whichever child has compactSaving, so this row stands
    // in for the label it holds.
    property bool compact: false
    readonly property real compactSaving: dancing ? shown.advanceWidth + spacing : label.compactSaving

    spacing: dancing && label.text !== "" ? 7 : 0

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
      id: label

      anchors.verticalCenter: parent.verticalCenter
      icon: content.dancing ? "" : root.icon
      text: content.dancing && content.compact ? "" : metrics.elidedText
      compact: content.compact
      color: (root.player && root.player.isPlaying) ? Color.barAccent : Color.barMuted
      lively: !!root.player && root.player.isPlaying && !content.dancing
    }
  }
}
