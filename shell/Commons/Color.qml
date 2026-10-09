pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Theme colors for the shell.
//
// The active theme is reached through the symlink chain that install/config/theme.sh
// sets up: ~/.config/desktop/current/theme -> ~/.config/desktop/themes/<name>. A theme
// contributes colors by shipping a shell.json next to its waybar.css and mako.ini.
//
// Every role below has a hard-coded default, so a third-party theme cloned by
// desktop-theme-install -- which will not have a shell.json -- still renders a legible
// bar instead of black on black.
QtObject {
  id: root

  readonly property string home: Quickshell.env("HOME")
  readonly property string themePath: home + "/.config/desktop/current/theme"

  // Foundational palette.
  property color background: "#11111b"
  property color foreground: "#c0caf5"
  property color muted: "#565f89"
  property color accent: "#7aa2f7"
  property color urgent: "#f7768e"
  // The opposite of urgent: something went well and is there to be picked up.
  property color good: "#9ece6a"
  // The two steps between good and urgent, for something that runs out by degrees.
  property color caution: "#e0af68"
  property color warning: "#ff9e64"

  // Per-surface roles. Default to the foundational palette so a theme only has to
  // override what it actually cares about.
  property color barBackground: background
  property color barText: foreground
  property color barMuted: muted
  property color barAccent: accent
  property color barUrgent: urgent
  property color barGood: good
  property color barActiveWorkspace: accent
  // The filled box behind each workspace number. Derived from barText rather than named
  // as a hex the way waybar's #1e1e2e was: a fixed colour is only right for one theme,
  // and a lift off whatever the bar is sitting on is right for all of them.
  property color barWorkspaceBackground: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.08)
  property color barHover: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.1)

  // Popup surfaces. Same contract as the bar roles: each defaults to a foundational
  // colour, so a theme that ships no `popup` subtree still renders a legible panel.
  property color popupBackground: background
  property color popupText: foreground
  property color popupMuted: muted
  property color popupAccent: accent
  property color popupUrgent: urgent
  property color popupBorder: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.18)
  property color popupHover: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.1)
  property color popupSelected: Qt.rgba(accent.r, accent.g, accent.b, 0.18)

  // Tooltip surface. Defaults to the popup roles so a theme that says nothing about
  // tooltips still matches its own panels.
  property color tooltipBackground: popupBackground
  property color tooltipText: popupText
  property color tooltipBorder: popupBorder

  // How far gone something is, as a colour: good while there is plenty left, through
  // caution and warning, to urgent when it is spent. Blended between the stops rather than
  // stepped, so 60% and 70% are told apart without anyone learning where a threshold sits.
  function gauge(fraction) {
    var stops = [[0, good], [0.5, caution], [0.75, warning], [1, urgent]];
    var at = Math.max(0, Math.min(1, fraction));
    for (var i = 1; i < stops.length; i++) {
      if (at <= stops[i][0]) {
        var from = stops[i - 1], to = stops[i];
        var t = (at - from[0]) / (to[0] - from[0]);
        return Qt.rgba(from[1].r + (to[1].r - from[1].r) * t,
                       from[1].g + (to[1].g - from[1].g) * t,
                       from[1].b + (to[1].b - from[1].b) * t, 1);
      }
    }
    return urgent;
  }

  // Reassigning the whole object is what makes bindings re-evaluate; mutating it in
  // place would not.
  property var values: ({})

  function pick(obj, key, fallback) {
    if (!obj)
      return fallback;
    var v = obj[key];
    return (typeof v === "string" && v.length > 0) ? v : fallback;
  }

  function apply(text) {
    var parsed = {};
    try {
      parsed = JSON.parse(text) || {};
    } catch (e) {
      console.warn("Color: could not parse theme shell.json:", e);
      return;
    }

    values = parsed;

    background = pick(parsed, "background", "#11111b");
    foreground = pick(parsed, "foreground", "#c0caf5");
    muted = pick(parsed, "muted", "#565f89");
    accent = pick(parsed, "accent", "#7aa2f7");
    urgent = pick(parsed, "urgent", "#f7768e");
    good = pick(parsed, "good", "#9ece6a");
    caution = pick(parsed, "caution", "#e0af68");
    warning = pick(parsed, "warning", "#ff9e64");

    var bar = parsed.bar || {};
    barBackground = pick(bar, "background", background);
    barText = pick(bar, "text", foreground);
    barMuted = pick(bar, "muted", muted);
    barAccent = pick(bar, "accent", accent);
    barUrgent = pick(bar, "urgent", urgent);
    barGood = pick(bar, "good", good);
    barActiveWorkspace = pick(bar, "activeWorkspace", barAccent);
    barHover = Qt.rgba(barText.r, barText.g, barText.b, 0.1);
    barWorkspaceBackground = pick(bar, "workspaceBackground", Qt.rgba(barText.r, barText.g, barText.b, 0.08));

    var popup = parsed.popup || {};
    popupBackground = pick(popup, "background", background);
    popupText = pick(popup, "text", foreground);
    popupMuted = pick(popup, "muted", muted);
    popupAccent = pick(popup, "accent", accent);
    popupUrgent = pick(popup, "urgent", urgent);
    popupBorder = pick(popup, "border", Qt.rgba(popupText.r, popupText.g, popupText.b, 0.18));
    popupHover = Qt.rgba(popupText.r, popupText.g, popupText.b, 0.1);
    popupSelected = Qt.rgba(popupAccent.r, popupAccent.g, popupAccent.b, 0.18);

    var tooltip = parsed.tooltip || {};
    tooltipBackground = pick(tooltip, "background", popupBackground);
    tooltipText = pick(tooltip, "text", popupText);
    tooltipBorder = pick(tooltip, "border", popupBorder);
  }

  // Re-read the theme file. The path is unchanged -- it is the symlink target that
  // moved -- so this is a reload rather than a rebind.
  function reload() {
    themeFile.reload();
  }

  // watchChanges is off on purpose: this path is a symlink, and swapping the symlink
  // target does not reliably fire an inotify watch on the resolved file. Theme changes
  // arrive as a reloadTheme IPC call from desktop-theme-set instead.
  property FileView themeFile: FileView {
    path: root.themePath + "/shell.json"
    watchChanges: false
    onLoaded: root.apply(text())
    onLoadFailed: console.warn("Color: no shell.json in", root.themePath, "- using built-in palette")
  }
}
