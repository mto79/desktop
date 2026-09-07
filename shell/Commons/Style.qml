pragma Singleton

import QtQuick

// Sizing, spacing and font for the shell.
//
// The font family is deliberately not themed: it resolves through the fontconfig
// "monospace" alias, which bin/desktop-font-set already rewrites in
// ~/.config/fontconfig/fonts.conf. Setting a font there updates the bar too.
QtObject {
  id: root

  property string fontFamily: "monospace"
  property int fontSize: 13
  property int iconSize: 15
  // Tray icons are raster images from the applications, not glyphs from the bar font,
  // and read a little smaller at the same nominal size. Its own token so the two can be
  // balanced by eye; overridable per layout with {"id": "tray", "iconSize": 18}.
  property int trayIconSize: 16

  // Bar geometry. barSize is overridden from shell.json's bar.height.
  property int barSize: 38
  property int itemSpacing: 2
  property int itemPaddingH: 6
  property int sectionSpacing: 8
  // The gap a bar spacer leaves between groups of widgets. Its own token rather than
  // sectionSpacing, which sizes gaps inside popups: this one only has to beat
  // itemPaddingH by enough that the eye reads a break, and 8 did not.
  property int barGroupSpacing: 14
  property int radius: 0

  // Popup / panel geometry.
  property int popupWidth: 360
  property int popupPadding: 12
  property int popupGap: 4          // gap between the bar edge and the popup
  property int popupMargin: 8       // minimum gap to the screen edge
  property int rowHeight: 34
  property int rowSpacing: 2

  // Tooltip geometry. The delay is what keeps a tooltip off the screen while the
  // pointer is only crossing the bar on its way somewhere else.
  property int tooltipPaddingH: 10
  property int tooltipPaddingV: 6
  property int tooltipMaxWidth: 320
  property int tooltipDelay: 450

  function space(n) {
    return n * 4;
  }
}
