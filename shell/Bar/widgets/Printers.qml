import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Printers: the printers within reach, as one mark -- red when one has a problem (out of
// paper, a jam, offline), the accent while one prints, amber when an ink or toner is low,
// muted while all are idle, and gone when there is no printer on this network.
//
// It reads what desktop-printers.timer leaves behind every two minutes rather than asking
// the printers itself: asking takes seconds over the network, and the timer is what sends
// the popup when a printer needs you, which a shell restart must not send again.
//
// The tooltip has each printer's ink, a click opens the printer's own web page -- its
// settings, its supplies -- and a right click CUPS's own page of the printers it has.
BarItem {
  id: root

  property var info: null

  readonly property var printers: info && info.printers ? info.printers : []
  readonly property string worst: info && info.worst ? info.worst : "none"
  readonly property int jobs: printers.reduce(function (sum, p) {
    return sum + (p.jobs || 0);
  }, 0)
  readonly property var first: {
    for (var i = 0; i < printers.length; i++)
      if (printers[i].problems.length > 0)
        return printers[i];
    return printers.length > 0 ? printers[0] : null;
  }

  visible: printers.length > 0
  implicitWidth: visible ? content.implicitWidth + Style.itemPaddingH * 2 : 0

  FileView {
    path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/desktop/printers.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try {
        root.info = JSON.parse(text());
      } catch (e) {}
    }
  }

  command: first && first.web ? ["xdg-open", first.web] : null
  rightCommand: ["xdg-open", "http://localhost:631/printers/"]

  tooltip: {
    var lines = [];
    for (var i = 0; i < printers.length; i++) {
      var p = printers[i];
      if (i > 0)
        lines.push("");
      var state = p.problems.length > 0 ? p.problems.join(", ") : (p.state === "processing" ? "printing" : p.state);
      lines.push(p.name + "  ·  " + state + (p.jobs > 0 ? "  ·  " + p.jobs + " queued" : ""));
      for (var j = 0; j < p.inks.length; j++)
        lines.push("  " + p.inks[j].name + "  " + p.inks[j].level + "%" + (p.inks[j].level < 15 ? "  low" : ""));
    }
    lines.push("", "Click for the printer's page  ·  right-click for CUPS");
    return lines.join("\n");
  }

  IconLabel {
    id: content

    icon: "\u{f042a}"
    text: root.jobs > 0 ? String(root.jobs) : ""
    color: root.worst === "error" ? Color.barUrgent : root.worst === "printing" ? Color.barAccent : root.worst === "low" ? Color.barAttention : Color.barMuted
  }
}
