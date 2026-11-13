// Which of a bar section's widgets give up their text, when the section has run out of
// room beside the centred clock.
//
// Kept free of QML so node can run it: test/shell-test.sh does.
//
// `able` holds the widgets that have something to give: { compactSaving, compactOrder,
// compactKeepsText, compact }. `full` is the section's width with every one of them at full
// size. Each is set compact or not, in this order:
//
//   - those that would rather keep their text ({"keepText": true}) are asked last;
//   - before any of the rest loses its text altogether, those that keep a short form are
//     shortened -- the CPU gives up its graph and keeps its number;
//   - then the one that gives the most back goes first, so as few as possible lose theirs.
function choose(full, maxWidth, able) {
  var order = able.slice();
  order.sort(function (a, b) {
    return (a.compactOrder - b.compactOrder) || ((b.compactKeepsText ? 1 : 0) - (a.compactKeepsText ? 1 : 0))
      || (b.compactSaving - a.compactSaving);
  });
  for (var i = 0; i < order.length; i++) {
    var over = full > maxWidth;
    if (over)
      full -= order[i].compactSaving;
    order[i].compact = over;
  }
  return full;
}

if (typeof module !== "undefined")
  module.exports = { choose: choose };
