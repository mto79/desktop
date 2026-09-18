// Dutch public holidays for a year, as [{date: Date, name: "Koningsdag"}] in date order.
//
// Computed, not fetched: every one is either fixed or hangs off Easter, so a year needs
// no calendar service and no network -- and this machine has neither a calendar nor
// access to the one at work. Names are Dutch, since the days are.
//
// Goede Vrijdag and Bevrijdingsdag are listed although neither is a day off for everyone:
// both are days people plan around. Koningsdag moves to the 26th when the 27th is a
// Sunday, as the law has it.
//
// Kept free of QML so node can run it: test/holidays-test.sh does.

// Easter Sunday, by the anonymous Gregorian algorithm (Meeus/Jones/Butcher).
function easter(year) {
  var a = year % 19;
  var b = Math.floor(year / 100);
  var c = year % 100;
  var d = Math.floor(b / 4);
  var e = b % 4;
  var f = Math.floor((b + 8) / 25);
  var g = Math.floor((b - f + 1) / 3);
  var h = (19 * a + b - d - g + 15) % 30;
  var i = Math.floor(c / 4);
  var k = c % 4;
  var l = (32 + 2 * e + 2 * i - h - k) % 7;
  var m = Math.floor((a + 11 * h + 22 * l) / 451);
  var month = Math.floor((h + l - 7 * m + 114) / 31);
  var day = ((h + l - 7 * m + 114) % 31) + 1;
  return new Date(year, month - 1, day);
}

function offset(date, days) {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate() + days);
}

function netherlands(year) {
  var e = easter(year);
  var kings = new Date(year, 3, 27);
  if (kings.getDay() === 0)
    kings = new Date(year, 3, 26);
  var list = [
    { date: new Date(year, 0, 1), name: "Nieuwjaarsdag" },
    { date: offset(e, -2), name: "Goede Vrijdag" },
    { date: e, name: "Eerste Paasdag" },
    { date: offset(e, 1), name: "Tweede Paasdag" },
    { date: kings, name: "Koningsdag" },
    { date: new Date(year, 4, 5), name: "Bevrijdingsdag" },
    { date: offset(e, 39), name: "Hemelvaartsdag" },
    { date: offset(e, 49), name: "Eerste Pinksterdag" },
    { date: offset(e, 50), name: "Tweede Pinksterdag" },
    { date: new Date(year, 11, 25), name: "Eerste Kerstdag" },
    { date: new Date(year, 11, 26), name: "Tweede Kerstdag" }
  ];
  list.sort(function (x, y) { return x.date - y.date; });
  return list;
}

// "2026-4-27" -> name, for the grid to look a day up without scanning the list.
function key(date) {
  return date.getFullYear() + "-" + (date.getMonth() + 1) + "-" + date.getDate();
}

function lookup(year) {
  var map = {};
  var list = netherlands(year);
  for (var i = 0; i < list.length; i++)
    map[key(list[i].date)] = list[i].name;
  return map;
}

// The next `count` holidays on or after `from`, across the turn of the year.
function upcoming(from, count) {
  var start = new Date(from.getFullYear(), from.getMonth(), from.getDate());
  var list = netherlands(start.getFullYear()).concat(netherlands(start.getFullYear() + 1));
  return list.filter(function (h) { return h.date >= start; }).slice(0, count);
}

if (typeof module !== "undefined")
  module.exports = { easter: easter, netherlands: netherlands, lookup: lookup, key: key, upcoming: upcoming };
