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

  // Is there an active link with a stream of this kind at that end of it?
  function flowing(groups, end, kind) {
    for (var i = 0; i < groups.length; i++) {
      var group = groups[i];
      var node = group ? group[end] : null;
      if (group && group.state === PwLinkState.Active && node && node.type === kind)
        return true;
    }
    return false;
  }

  readonly property var groups: Pipewire.linkGroups ? Pipewire.linkGroups.values : []
  // A playback stream sends; a recording stream takes. Matching the exact type leaves out
  // the Bluetooth headset's own internal capture stream, and video.
  readonly property bool playing: flowing(groups, "source", PwNodeType.AudioOutStream)
  readonly property bool recording: flowing(groups, "target", PwNodeType.AudioInStream)

  // Untracked, a link reads state -1 and a node type 0.
  PwObjectTracker {
    objects: root.groups
  }
}
