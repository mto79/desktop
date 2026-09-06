pragma Singleton

import QtQuick

// Date arithmetic that Qt does not do for us.
QtObject {
  id: root

  // ISO-8601 week number. Qt's date formatting has no week specifier at all -- a
  // format string of "'W'ww" renders the literal "Www" -- so anything that wants a
  // week number has to compute it and paste it in.
  //
  // Week 1 is the one containing the first Thursday of the year, so shifting any date
  // to its own Thursday makes both the week number and the week-numbering year fall
  // out of a single subtraction.
  function isoWeek(date) {
    var thursday = new Date(date.getFullYear(), date.getMonth(), date.getDate());
    thursday.setDate(thursday.getDate() + 3 - ((thursday.getDay() + 6) % 7));
    var firstThursday = new Date(thursday.getFullYear(), 0, 4);
    firstThursday.setDate(firstThursday.getDate() + 3 - ((firstThursday.getDay() + 6) % 7));
    return 1 + Math.round((thursday - firstThursday) / (7 * 24 * 3600 * 1000));
  }
}
