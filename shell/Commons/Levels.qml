pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "levels.js" as Parse

// The default output's and microphone's volume and mute, as PipeWire has them. Once, for
// every bar on every screen, the panels and the overlay.
//
// Not Quickshell's own `audio.muted` and `audio.volume`. Quickshell (0.3.2) keeps a copy
// of each and never asks again after a device comes back: when the headset's Bluetooth
// link dropped and reconnected, the bar said muted for the rest of the afternoon while
// PipeWire, and the ears, said 80%. Unbinding a node leaves its mute where it was, and
// nothing re-reads a Bluetooth route after an error.
//
// So `pactl subscribe` says when something changed and `wpctl get-volume` says what it is
// now. One long-running process and a short one per change -- a mute, a volume step, a
// different default -- and none while nothing happens. Writes still go through
// Quickshell or wpctl; the answer comes back here either way.
Singleton {
  id: root

  property bool sinkKnown: false
  property real sinkVolume: 0
  property bool sinkMuted: false

  property bool sourceKnown: false
  property real sourceVolume: 0
  property bool sourceMuted: false

  // Mute toggles go through wpctl rather than `audio.muted = !audio.muted`: with a stale
  // copy that sets the mute it already has, and the click does nothing.
  function toggleSinkMute() {
    Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]);
  }

  function toggleSourceMute() {
    Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"]);
  }

  function unmuteSource() {
    Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "0"]);
  }

  function refresh() {
    if (reader.running)
      again = true;
    else
      reader.running = true;
  }

  // A change that lands while one read is under way gets a read of its own after it,
  // rather than being lost to the one that started before it.
  property bool again: false

  Process {
    id: reader

    command: ["sh", "-c",
      "printf 'sink '; wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null; echo; " +
      "printf 'source '; wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null; echo"]

    stdout: StdioCollector {
      onStreamFinished: {
        var found = Parse.parse(text);
        root.sinkKnown = !!found.sink;
        if (found.sink) {
          root.sinkVolume = found.sink.volume;
          root.sinkMuted = found.sink.muted;
        }
        root.sourceKnown = !!found.source;
        if (found.source) {
          root.sourceVolume = found.source.volume;
          root.sourceMuted = found.source.muted;
        }
      }
    }

    onExited: if (root.again) {
      root.again = false;
      running = true;
    }
  }

  // A volume drag is a burst of events; one read after it settles is enough for the bar,
  // and short enough that the overlay still follows the key that was pressed.
  Timer {
    id: settle

    interval: 40
    onTriggered: root.refresh()
  }

  Process {
    id: watcher

    command: ["pactl", "subscribe"]
    running: true

    stdout: SplitParser {
      onRead: line => {
        if (Parse.matters(line))
          settle.restart();
      }
    }

    // pipewire-pulse restarts with PipeWire. Read again once it is back, since whatever
    // changed meanwhile went unannounced.
    onRunningChanged: if (running)
      root.refresh()
    onExited: rewatch.start()
  }

  Timer {
    id: rewatch

    interval: 2000
    onTriggered: watcher.running = true
  }
}
