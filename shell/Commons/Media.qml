pragma Singleton

import QtQuick
import Quickshell.Services.Mpris

// Which MPRIS player the bar is talking about.
//
// A singleton because the bar widget and the media panel have to agree, and there is
// one of each per monitor and one panel in total. Selection is a dbus name rather than
// an object: players come and go, and a pin that survives a restart of the player it
// names is worth more than one that holds a dangling reference.
QtObject {
  id: root

  readonly property var players: Mpris.players ? Mpris.players.values : []

  // Pinned by clicking a row in the panel. Empty means "whatever makes sense".
  property string preferred: ""

  // Preference order: the pinned player if it is still around, then whatever is
  // actually playing, then the first one to have appeared. Reading isPlaying inside the
  // loop is what makes this re-evaluate when playback starts somewhere else.
  readonly property var active: {
    var i;
    if (preferred !== "")
      for (i = 0; i < players.length; i++)
        if (players[i].dbusName === preferred)
          return players[i];

    for (i = 0; i < players.length; i++)
      if (players[i].isPlaying)
        return players[i];

    return players.length > 0 ? players[0] : null;
  }

  readonly property bool available: active !== null

  function select(player) {
    preferred = player ? player.dbusName : "";
  }

  function label(player) {
    if (!player)
      return "";
    var title = player.trackTitle || "";
    var artist = player.trackArtist || "";
    if (title === "")
      return player.identity || player.dbusName;
    return artist === "" ? title : artist + " - " + title;
  }

  // MPRIS reports seconds as a double; anything not yet known comes back as zero or
  // negative, which should read as blank rather than as 0:00.
  function time(seconds) {
    if (!seconds || seconds <= 0)
      return "";
    var total = Math.floor(seconds);
    var minutes = Math.floor(total / 60);
    var rest = total % 60;
    return minutes + ":" + (rest < 10 ? "0" : "") + rest;
  }
}
