pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Whether sound is going anywhere: out to a speaker, in from a microphone. Once, for
// every bar on every screen.
//
// Asked of the links between nodes rather than of the nodes. A program has a stream for
// as long as it means to play or record, but the link from it is only active while the
// graph is running it: a stream that has gone quiet is suspended and its link is not. A
// player that says it is playing is no guide either -- a call in a browser is not a player.
Singleton {
  id: root

  // Is there an active link with a stream of this kind at that end of it? With
  // `notFromSink`, one whose other end is not a sink, which is how a recording of what
  // the speakers play looks.
  function flowing(groups, end, kind, notFromSink) {
    for (var i = 0; i < groups.length; i++) {
      var group = groups[i];
      var node = group ? group[end] : null;
      if (!group || group.state !== PwLinkState.Active || !node || node.type !== kind)
        continue;
      if (notFromSink && group.source && group.source.isSink)
        continue;
      return true;
    }
    return false;
  }

  readonly property var groups: Pipewire.linkGroups ? Pipewire.linkGroups.values : []
  // A playback stream sends; a recording stream takes. Matching the exact type leaves out
  // the Bluetooth headset's own internal capture stream, and video.
  readonly property bool playing: flowing(groups, "source", PwNodeType.AudioOutStream)
  // From a microphone, that is. cava, which draws the media widget's equalizer, records
  // too -- from the speakers' monitor -- so while music played the microphone read as in
  // use. Not "from an AudioSource" instead: a noise-suppressing or echo-cancelling
  // microphone is an Audio/Source/Virtual node, which Quickshell gives no type at all.
  readonly property bool recording: flowing(groups, "target", PwNodeType.AudioInStream, true)

  // Untracked, a link reads state -1 and a node type 0.
  PwObjectTracker {
    objects: root.groups
  }
}
