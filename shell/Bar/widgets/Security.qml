import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Security: a shield that says whether desktop-security found anything, and how much.
//
// It reads the result the fifteen-minute timer leaves behind rather than running the
// check itself -- that takes seconds, and one checker is enough. The file is watched, so
// the shield changes the moment a check finishes, from the timer or from the panel.
//
// Muted when all is clear: a shield that is always loud stops being looked at. Accent
// for something to look at, urgent for something to act on, with the count beside it.
BarItem {
  id: root

  property var result: null

  readonly property var findings: result ? result.findings.filter(function (f) {
    return f.level !== "info";
  }) : []
  readonly property int bad: findings.filter(function (f) {
    return f.level === "bad";
  }).length

  FileView {
    path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/desktop/security/last.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try {
        root.result = JSON.parse(text());
      } catch (e) {}
    }
  }

  tooltip: {
    if (!result)
      return "Security  ·  not checked yet";
    if (findings.length === 0)
      return "Security  ·  nothing to act on";
    var lines = ["Security"];
    for (var i = 0; i < Math.min(findings.length, 4); i++)
      lines.push(findings[i].title);
    return lines.join("\n");
  }

  panelId: "security"

  onClicked: if (popups)
    popups.toggle(root.panelId, this)

  IconLabel {
    icon: root.bad > 0 ? "\u{f0565}" : (root.findings.length > 0 ? "\u{f0e1e}" : "\u{f0565}")
    text: root.findings.length > 0 ? String(root.findings.length) : ""
    color: root.bad > 0 ? Color.barUrgent : (root.findings.length > 0 ? Color.barAccent : Color.barMuted)
  }
}
