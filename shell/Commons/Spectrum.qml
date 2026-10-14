pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// What the music sounds like, as a dozen levels from bass to treble: the bar's equalizer.
//
// cava does the listening -- it taps PipeWire's output and does the FFT -- and prints a
// frame per line. One process for the whole shell, here, because the media widget exists
// once per monitor and three cavas would each be listening to the same thing.
//
// It runs only while a player is actually playing. Paused, the process is stopped rather
// than left reading silence thirty times a second.
QtObject {
  id: root

  // Levels from 0 to 1, bass first. Empty while cava is not running.
  property var levels: []

  // Whether there is a reading at all. False when cava is not installed or has not
  // printed its first frame yet, which is what the widget falls back to its glyph on.
  readonly property bool live: levels.length > 0

  readonly property bool wanted: Media.active !== null && Media.active.isPlaying

  readonly property string configPath: Quickshell.env("DESKTOP_PATH") + "/default/cava/spectrum.conf"

  onWantedChanged: if (!wanted)
    levels = []

  // `12;480;1000;...;` -- the trailing delimiter leaves an empty last field. cava sets
  // the terminal title before its first frame, escape code and all, on stdout; a line
  // that is not all numbers keeps the last reading rather than becoming one.
  function parse(line) {
    if (!/^[0-9;]+$/.test(line))
      return levels;
    var fields = line.split(";");
    var out = [];
    for (var i = 0; i < fields.length; i++)
      if (fields[i] !== "")
        out.push(Math.max(0, Math.min(1, parseInt(fields[i], 10) / 1000)));
    return out;
  }

  property Process cava: Process {
    command: ["cava", "-p", root.configPath]
    running: root.wanted

    stdout: SplitParser {
      onRead: line => root.levels = root.parse(line)
    }

    onExited: root.levels = []
  }
}
