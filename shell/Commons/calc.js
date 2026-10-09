// The launcher's calculator: "= 1920 / 1.6".
//
// Kept free of QML so node can run it: test/launcher-test.sh does.
//
// Arithmetic, and nothing else. What is typed is only ever evaluated after every
// character of it has been accounted for: digits, operators, brackets, and the handful
// of names below. Anything else -- a letter that is not part of one of those names, a
// quote, a semicolon -- and there is no answer, so nothing typed here can be code.
var NAMES = {
    "sqrt": "Math.sqrt",
    "abs": "Math.abs",
    "round": "Math.round",
    "floor": "Math.floor",
    "ceil": "Math.ceil",
    "sin": "Math.sin",
    "cos": "Math.cos",
    "tan": "Math.tan",
    "log": "Math.log10",
    "ln": "Math.log",
    "min": "Math.min",
    "max": "Math.max",
    "pi": "Math.PI",
    "e": "Math.E"
};

function calculate(text) {
  var source = text.trim().toLowerCase();
  if (source === "")
    return null;
  var built = "";
  var i = 0;
  while (i < source.length) {
    var ch = source.charAt(i);
    if (/[a-z]/.test(ch)) {
      var end = i;
      while (end < source.length && /[a-z]/.test(source.charAt(end)))
        end++;
      var word = source.slice(i, end);
      // Its own names only. Asked plainly, an object also answers to "constructor", and
      // that is not a name anyone gave it.
      if (!Object.prototype.hasOwnProperty.call(NAMES, word))
        return null;
      built += NAMES[word];
      i = end;
    } else if (/[0-9.+\-*\/%() ]/.test(ch)) {
      built += ch;
      i++;
    } else if (ch === "^") {
      built += "**";
      i++;
    } else if (ch === ",") {
      // A decimal comma between two digits, an argument separator anywhere else.
      var decimal = /[0-9]/.test(source.charAt(i - 1)) && /[0-9]/.test(source.charAt(i + 1)) && built.indexOf("Math.m") === -1;
      built += decimal ? "." : ",";
      i++;
    } else {
      return null;
    }
  }
  try {
    var value = Function('"use strict"; return (' + built + ");")();
    if (typeof value !== "number" || !isFinite(value))
      return null;
    // Twelve significant digits: enough for anything typed here, and it keeps
    // 0.1 + 0.2 from answering 0.30000000000000004.
    return String(parseFloat(value.toPrecision(12)));
  } catch (error) {
    return null;
  }
}

if (typeof module !== "undefined")
  module.exports = { calculate: calculate };
