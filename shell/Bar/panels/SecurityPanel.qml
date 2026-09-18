import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Security panel: what desktop-security found, most urgent first, with the fix for each.
//
// Laid out like the battery panel: how many things need attention, big, and the
// machine's security basics in a grid -- SELinux, firewall, disk encryption, Secure Boot,
// firmware, pending security fixes -- since those are what an audit starts from. Each
// finding opens on click to show what to do about it; the checks that passed fold into
// one row, because a list of green lines buries the one that is not.
//
// The quick check runs from a timer every fifteen minutes and this panel reads what it
// left, re-running it only when that is stale. The full audit needs root, so it runs in
// a terminal where sudo can ask; its verdicts show here until the next one.
Popup {
  id: root

  readonly property string panelId: "security"

  readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/desktop/security"

  property var result: null
  property var audit: null
  property bool checking: false
  property string expanded: ""
  property bool showPassed: false
  property string copied: ""
  property int tick: 0

  readonly property var findings: result ? result.findings : []
  readonly property var facts: result ? result.facts : ({})
  readonly property int badCount: findings.filter(function (f) {
    return f.level === "bad";
  }).length
  readonly property int warnCount: findings.filter(function (f) {
    return f.level === "warn";
  }).length
  // Change findings are cleared by accepting what is there now.
  readonly property bool hasChanges: findings.some(function (f) {
    return f.id.indexOf("new-") === 0;
  })

  function ago(seconds) {
    root.tick;
    if (!seconds)
      return "never";
    var minutes = Math.floor((Date.now() / 1000 - seconds) / 60);
    if (minutes < 1)
      return "just now";
    if (minutes < 60)
      return minutes + " min ago";
    if (minutes < 60 * 48)
      return Math.floor(minutes / 60) + " h ago";
    return Math.floor(minutes / 1440) + " days ago";
  }

  function levelIcon(level) {
    return level === "bad" ? "\u{f0028}" : (level === "warn" ? "\u{f0026}" : "\u{f02fc}");
  }

  function levelColor(level) {
    return level === "bad" ? Color.popupUrgent : (level === "warn" ? Color.popupAccent : Color.popupMuted);
  }

  function launch(command) {
    Quickshell.execDetached({
      command: command,
      workingDirectory: Quickshell.env("HOME")
    });
  }

  FileView {
    id: lastFile

    path: root.stateDir + "/last.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try {
        root.result = JSON.parse(text());
      } catch (e) {}
    }
  }

  FileView {
    id: auditFile

    path: root.stateDir + "/audit-last.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try {
        root.audit = JSON.parse(text());
      } catch (e) {}
    }
  }

  // The check writes last.json itself, which the FileView above picks up.
  Process {
    id: checker

    command: ["desktop-security", "check", "--json"]
    stdout: StdioCollector {}
    onExited: root.checking = false
  }

  Process {
    id: accepter

    command: ["desktop-security", "accept"]
    stdout: StdioCollector {}
    onExited: root.checkNow()
  }

  function checkNow() {
    if (checker.running)
      return;
    checking = true;
    checker.running = true;
  }

  onVisibleChanged: {
    if (!visible) {
      expanded = "";
      showPassed = false;
      return;
    }
    // Stale after the timer's own interval: it has missed a run, or never had one.
    if (!result || Date.now() / 1000 - result.checked > 16 * 60)
      checkNow();
  }

  Timer {
    interval: 30000
    repeat: true
    running: root.visible
    onTriggered: root.tick++
  }

  Timer {
    id: copiedTimer

    interval: 1400
    onTriggered: root.copied = ""
  }

  contentWidth: Style.popupWidth
  contentHeight: column.implicitHeight + Style.popupPadding * 2

  Column {
    id: column

    width: parent.width
    spacing: 2

    PanelHero {
      icon: root.badCount > 0 ? "\u{f0565}" : (root.warnCount > 0 ? "\u{f0e1e}" : "\u{f0565}")
      iconColor: root.badCount > 0 ? Color.popupUrgent : (root.warnCount > 0 ? Color.popupAccent : Color.popupText)
      title: "Security"
      spinning: root.checking
      status: {
        if (root.checking && !root.result)
          return "checking...";
        if (!root.result)
          return "not checked yet";
        var parts = [];
        if (root.badCount > 0)
          parts.push(root.badCount + " to act on");
        if (root.warnCount > 0)
          parts.push(root.warnCount + " to look at");
        if (parts.length === 0)
          parts.push("nothing to act on");
        parts.push("checked " + root.ago(root.result.checked));
        return parts.join("  ·  ");
      }
      statusColor: root.badCount > 0 ? Color.popupUrgent : (root.warnCount > 0 ? Color.popupAccent : Color.popupMuted)
      value: root.result ? String(root.badCount + root.warnCount) : "—"
      valueColor: root.badCount > 0 ? Color.popupUrgent : (root.warnCount > 0 ? Color.popupAccent : Color.popupMuted)
    }

    Grid {
      width: parent.width
      columns: 2
      topPadding: 2
      bottomPadding: 4
      visible: !!root.result

      PanelStat {
        label: "SELinux"
        value: root.facts.selinux ? root.facts.selinux.toLowerCase() : "—"
        warn: root.facts.selinux !== undefined && root.facts.selinux !== "Enforcing"
      }
      PanelStat {
        label: "Firewall"
        value: Array.isArray(root.facts.firewall) ? root.facts.firewall.join(" ") : (root.facts.firewall || "—")
        warn: root.facts.firewall === "off"
      }
      PanelStat {
        label: "Disk"
        value: root.facts.encrypted === undefined ? "—" : (root.facts.encrypted ? "encrypted" : "plain")
        warn: root.facts.encrypted === false
      }
      PanelStat {
        label: "Secure Boot"
        value: root.facts.secureBoot === undefined ? "—" : (root.facts.secureBoot ? "on" : "off")
        warn: root.facts.secureBoot === false
      }
      PanelStat {
        label: "Firmware"
        value: root.facts.hsi !== undefined ? "HSI " + root.facts.hsi + " / 5" : "—"
        muted: true
      }
      PanelStat {
        label: "Fixes due"
        value: root.facts.securityUpdates !== undefined ? String(root.facts.securityUpdates) : "—"
        warn: root.badCount > 0 && root.findings.some(function (f) {
          return f.id === "security-updates" && f.level === "bad";
        })
      }
    }

    // --- Findings, most urgent first ----------------------------------------------------
    PanelSection {
      title: "Findings"
      value: root.findings.length > 0 ? "click for the fix" : ""
      rule: true
      visible: root.findings.length > 0
    }

    Repeater {
      model: root.findings

      delegate: Column {
        id: finding

        required property var modelData

        readonly property bool open: root.expanded === modelData.id

        width: column.width

        PanelRow {
          icon: root.levelIcon(finding.modelData.level)
          accentColor: root.levelColor(finding.modelData.level)
          active: finding.modelData.level !== "info"
          label: finding.modelData.title
          sublabel: finding.open ? "" : finding.modelData.detail
          onClicked: root.expanded = finding.open ? "" : finding.modelData.id
          // The fix is usually a command; right click puts it on the clipboard.
          onRightClicked: {
            Quickshell.execDetached(["wl-copy", "--", finding.modelData.fix]);
            root.copied = finding.modelData.id;
            copiedTimer.restart();
          }

          Text {
            text: root.copied === finding.modelData.id ? "copied" : ""
            color: Color.popupAccent
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSize - 2
          }
        }

        // Open: the whole detail, wrapped, and what to do about it.
        Column {
          visible: finding.open
          width: parent.width
          leftPadding: 36
          rightPadding: 8
          bottomPadding: 8
          spacing: 6

          Text {
            width: parent.width - 44
            text: finding.modelData.detail
            color: Color.popupText
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSize - 2
            wrapMode: Text.Wrap
          }

          Text {
            width: parent.width - 44
            visible: finding.modelData.fix !== ""
            text: "Fix: " + finding.modelData.fix
            color: Color.popupAccent
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSize - 2
            wrapMode: Text.Wrap
          }

          Text {
            visible: finding.modelData.fix !== ""
            text: "right-click the row to copy it"
            color: Color.popupMuted
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSize - 3
          }
        }
      }
    }

    PanelRow {
      visible: root.hasChanges
      icon: "\u{f012c}"
      label: "These changes are mine"
      sublabel: "Record today's startup items and setuid programs as expected"
      onClicked: accepter.running = true
    }

    // --- What passed, folded ----------------------------------------------------------
    PanelRow {
      visible: !!root.result && root.result.passed.length > 0
      icon: "\u{f012c}"
      label: root.result ? root.result.passed.length + " checks passed" : ""
      sublabel: root.showPassed ? "click to fold" : "click to list them"
      onClicked: root.showPassed = !root.showPassed
    }

    Repeater {
      model: root.showPassed && root.result ? root.result.passed : []

      delegate: Text {
        required property var modelData

        leftPadding: 36
        width: column.width
        height: 20
        text: modelData.title
        color: Color.popupMuted
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSize - 2
        elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter
      }
    }

    // --- The root checks ----------------------------------------------------------------
    PanelSection {
      title: "Full audit"
      value: root.audit ? root.ago(root.audit.at) : "never run"
      rule: true
    }

    Repeater {
      model: root.audit ? root.audit.verdicts.filter(function (v) {
        return v.level !== "ok";
      }) : []

      delegate: PanelRow {
        required property var modelData

        icon: root.levelIcon(modelData.level)
        accentColor: root.levelColor(modelData.level)
        active: true
        label: modelData.title
        enabled: false
      }
    }

    PanelRow {
      icon: "\u{f0e1e}"
      label: root.audit ? "Audit again" : "Run the full audit"
      sublabel: "sshd, sudoers, logins, SELinux denials, every package file -- asks for sudo"
      onClicked: {
        root.close();
        root.launch(["desktop-launch-floating-terminal-with-presentation", "desktop-security", "audit"]);
      }
    }

    PanelRow {
      visible: !!root.audit
      icon: "\u{f0219}"
      label: "Read the last report"
      sublabel: root.audit ? root.audit.report.replace(Quickshell.env("HOME"), "~") : ""
      onClicked: {
        root.close();
        root.launch(["desktop-launch-editor", root.audit.report]);
      }
    }

    PanelRow {
      icon: "\u{f0450}"
      label: root.checking ? "Checking..." : "Check now"
      sublabel: "The quick checks run by themselves every fifteen minutes"
      enabled: !root.checking
      onClicked: root.checkNow()
    }
  }
}
