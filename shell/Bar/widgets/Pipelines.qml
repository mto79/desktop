import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Pipelines: the CI of your own open merge requests, as one mark in the colour of the
// worst -- failed, then running, then waiting, then passed.
//
// It reads what desktop-pipelines.timer leaves behind each minute rather than asking
// GitLab itself, as the security shield does: the timer is also what notifies when a
// pipeline finishes, and a shell restart must not ask again or say it all again. Hidden
// while you have nothing open, so it is there only when there is something to look at.
//
// A click opens the pipeline that matters most -- the first failed, or running, or
// waiting one -- and a right click your merge requests on GitLab. A draft counts only
// when its pipeline runs or failed; the tooltip lists it all the same.
BarItem {
  id: root

  property var info: null

  readonly property var requests: info && info.requests ? info.requests : []
  readonly property string worst: info && info.worst ? info.worst : "none"
  readonly property var withPipeline: requests.filter(function (r) {
    return r.status !== "none";
  })
  readonly property bool stale: requests.length > 0 && requests.every(function (r) {
    return r.stale;
  })
  readonly property var first: {
    var order = ["failed", "running", "pending", "success", "canceled", "none"];
    for (var i = 0; i < order.length; i++)
      for (var j = 0; j < requests.length; j++)
        if (requests[j].status === order[i] && requests[j].counts !== false)
          return requests[j];
    return null;
  }

  visible: requests.length > 0
  implicitWidth: visible ? content.implicitWidth + Style.itemPaddingH * 2 : 0

  FileView {
    path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/desktop/pipelines.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try {
        root.info = JSON.parse(text());
      } catch (e) {}
    }
  }

  command: first ? ["xdg-open", first.pipelineUrl] : null
  rightCommand: first ? ["xdg-open", "https://" + first.host + "/dashboard/merge_requests"] : null

  readonly property var words: ({
      "failed": "failed",
      "running": "running",
      "pending": "waiting",
      "success": "passed",
      "canceled": "cancelled",
      "none": "no pipeline"
    })

  tooltip: {
    var lines = ["Pipelines" + (stale ? "  ·  GitLab not reachable, as last seen" : "")];
    for (var i = 0; i < Math.min(requests.length, 8); i++) {
      var r = requests[i];
      lines.push(words[r.status] + "  " + r.ref + "  " + r.title);
    }
    if (requests.length > 8)
      lines.push("and " + (requests.length - 8) + " more");
    lines.push("", "Click for the " + (first ? words[first.status] : "") + " pipeline  ·  right-click for your merge requests");
    return lines.join("\n");
  }

  IconLabel {
    id: content

    // GitLab's mark when all is well or quiet; a running pipeline counts what runs.
    icon: "\u{f0ba0}"
    text: root.worst === "failed" || root.worst === "running" ? String(root.withPipeline.filter(function (r) {
      return r.status === root.worst;
    }).length) : ""
    color: root.stale ? Color.barMuted : root.worst === "failed" ? Color.barUrgent : root.worst === "running" ? Color.barAccent : root.worst === "pending" ? Color.barAttention : root.worst === "success" ? Color.barGood : Color.barMuted
  }
}
