// What `wpctl get-volume` says about the default output and microphone, and which of
// `pactl subscribe`'s events mean asking it again.
//
// Kept free of QML so node can run it: test/levels-test.sh does.

// Levels.qml asks for both at once and labels each answer, so a device that is missing --
// no microphone, say -- leaves its line bare rather than shifting the other into its place:
//
//   sink Volume: 0.80
//   source Volume: 0.55 [MUTED]
//   source
function parse(text) {
  var found = {};
  var lines = String(text).split("\n");
  for (var i = 0; i < lines.length; i++) {
    var match = /^(sink|source) Volume: ([0-9.]+)( \[MUTED\])?/.exec(lines[i].trim());
    if (!match)
      continue;
    found[match[1]] = { volume: parseFloat(match[2]), muted: !!match[3] };
  }
  return found;
}

// A change to a device or to which one is the default -- the server's -- is worth a
// fresh answer. A stream's is not: there are many of them, they change all through
// playback, and none of it moves the device's own volume or mute.
function matters(line) {
  return /^Event '[a-z]+' on (sink|source|server|card) #/.test(String(line).trim());
}

if (typeof module !== "undefined")
  module.exports = { parse: parse, matters: matters };
