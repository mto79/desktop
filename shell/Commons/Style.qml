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
  // Tray icons are raster images from the applications, not glyphs from the bar font:
  // full-colour artwork with their own outlines and fills, which is busier than a
  // single-weight glyph and reads as larger at the same nominal size. So they sit a
  // little under iconSize rather than a little over it, which is where this was while
  // the tray was drawing glyphs instead. Overridable per layout with
  // {"id": "tray", "iconSize": 18}.
  property int trayIconSize: 14

  // Bar geometry. barSize is overridden from shell.json's bar.height.
  property int barSize: 38
  property int itemSpacing: 2
  property int itemPaddingH: 4
  property int sectionSpacing: 8
  // The gap a bar spacer leaves between groups of widgets. Its own token rather than
  // sectionSpacing, which sizes gaps inside popups: this one only has to beat
  // itemPaddingH by enough that the eye reads a break, and 8 did not.
  property int barGroupSpacing: 14
  property int radius: 8
  // The bar's hover highlight only. Its own token because `radius` is the shell-wide
  // corner for panels, toasts and the launcher, and a hover pill a few pixels tall
  // wants a tighter one than a panel does.
  property int barRadius: 4
  // The gap between the bar and the screen edges it is anchored to. The bar's corners are
  // `radius`, and a bar flush with the edge has no visible corner to round.
  property int barInset: 4

  // The left section's two labels -- the workspace numbers and the window title. waybar
  // drew them a step larger and heavier than the readouts on the right, which is what
  // made that end of the bar read first at a glance. Their own tokens rather than a
  // raised fontSize: every panel in the shell is laid out around 13.
  property int barLabelSize: 14
  property int barLabelWeight: Font.DemiBold
  // The workspace pill. waybar's was a 6px-radius box with 0.6rem of air either side of
  // the number and 0.4rem clear of the bar edge. The gap between them is tighter than
  // waybar's 0.5rem: five pills in a row read as a row at 4, and as five things at 8.
  property int barWorkspaceRadius: 6
  property int barWorkspacePaddingH: 10
  property int barWorkspaceInsetV: 6
  property int barWorkspaceSpacing: 4

  // The tray drawer. Opening is delayed so that crossing the bar on the way somewhere
  // else does not unfold it -- the same trick tooltipDelay plays, and for the same
  // reason. Closing is delayed by more, because the pointer has to travel from the
  // chevron to the icons, and a drawer that shuts under it is worse than one that never
  // opened.
  property int trayOpenDelay: 180
  property int trayCloseDelay: 350
  property int trayFoldDuration: 200

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
