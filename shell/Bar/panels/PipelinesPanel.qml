import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "../widgets/pipelines.js" as Layout

// Pipelines panel: the CI of your open merge requests, a section for each GitLab.
//
// Laid out like the security and backup panels: the state in words under the title,
// the counts in a grid, then the detail. The detail is one section per GitLab instance
// desktop-pipelines asks -- every host glab is logged in to -- since there are several,
// and a merge request means little without knowing which GitLab it is on. A host off the
// VPN keeps what it last said, and its section says so.
//
// A row opens its pipeline; a right click opens the merge request. Failed, running and
// waiting rows are marked as the security panel marks its findings, in the colour the
// bar's GitLab mark takes for them; passed ones are plain. Merge requests without a
// pipeline are counted, and the count opens your merge requests on that GitLab.
//
// It reads what desktop-pipelines.timer leaves behind each minute, as the bar's mark
// does. Another GitLab is added with glab auth login, from the bottom of the panel.
Popup {
  id: root

  readonly property string panelId: "pipelines"

  property var info: null

  readonly property var sections: Layout.groups(info)
  readonly property var requests: info && info.requests ? info.requests : []
  readonly property string worst: info && info.worst ? info.worst : "none"

  function count(status) {
    return requests.filter(function (r) {
      return r.status === status;
    }).length;
  }

  function tone(status) {
    if (status === "failed")
      return Color.popupUrgent;
    if (status === "running")
      return Color.popupAccent;
    if (status === "pending")
      return Color.barAttention;
    if (status === "success")
      return Color.barGood;
    return Color.popupMuted;
  }

  function age(seconds) {
    if (!seconds)
      return "—";
    var minutes = Math.floor((Date.now() / 1000 - seconds) / 60);
    return minutes < 1 ? "just now" : minutes < 60 ? minutes + "m ago" : Math.floor(minutes / 60) + "h ago";
  }

  function openUrl(url) {
    root.close();
    Quickshell.execDetached(["xdg-open", url]);
  }

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

  // Asks every GitLab now rather than at the timer's next minute. The file it writes is
  // what the panel watches, so there is nothing to read back here.
  Process {
    id: checkNow

    command: ["desktop-pipelines"]
  }

  contentWidth: Style.popupWidth
  contentHeight: column.implicitHeight + Style.popupPadding * 2

  Column {
    id: column

    width: parent.width
    spacing: 2

    PanelHero {
      icon: "\u{f0ba0}"
      iconColor: root.tone(root.worst)
      title: "Pipelines"
      status: Layout.summary(root.info)
      statusColor: root.tone(root.worst)
      spinning: checkNow.running
      value: String(root.requests.length)
    }

    Grid {
      width: parent.width
      columns: 2
      topPadding: 2
      bottomPadding: 4

      PanelStat {
        label: "Failed"
        value: String(root.count("failed"))
        warn: root.count("failed") > 0
      }
      PanelStat {
        label: "Running"
        value: String(root.count("running"))
      }
      PanelStat {
        label: "Waiting"
        value: String(root.count("pending"))
      }
      PanelStat {
        label: "Passed"
        value: String(root.count("success"))
      }
      PanelStat {
        label: "GitLabs"
        value: String(root.sections.length)
      }
      PanelStat {
        label: "Checked"
        value: root.age(root.info ? root.info.checked : 0)
        muted: true
      }
    }

    Repeater {
      model: root.sections

      delegate: Column {
        id: section

        required property var modelData

        width: column.width
        spacing: 2

        PanelSection {
          title: section.modelData.host
          value: !section.modelData.reachable ? "not reachable" : section.modelData.open > 0 ? section.modelData.open + " open" : "nothing open"
          rule: true
        }

        Repeater {
          model: section.modelData.requests.slice(0, 8)

          delegate: PanelRow {
            required property var modelData

            icon: modelData.glyph
            active: modelData.urgent
            accentColor: root.tone(modelData.status)
            label: modelData.name
            sublabel: modelData.title
            onClicked: root.openUrl(modelData.pipelineUrl)
            onRightClicked: root.openUrl(modelData.url)

            Text {
              text: modelData.word
              color: root.tone(modelData.status)
              font.family: Style.fontFamily
              font.pixelSize: Style.fontSize - 2
            }
          }
        }

        PanelRow {
          visible: section.modelData.requests.length > 8
          icon: "\u{f01d8}"
          label: (section.modelData.requests.length - 8) + " more with a pipeline"
          sublabel: "your merge requests on " + section.modelData.host
          onClicked: root.openUrl("https://" + section.modelData.host + "/dashboard/merge_requests")
        }

        PanelRow {
          visible: section.modelData.without > 0
          icon: "\u{f0ba0}"
          label: section.modelData.without + " without a pipeline"
          sublabel: "your merge requests on " + section.modelData.host
          onClicked: root.openUrl("https://" + section.modelData.host + "/dashboard/merge_requests")
        }
      }
    }

    // No GitLab at all: say how to add one rather than show an empty panel.
    PanelRow {
      visible: root.sections.length === 0
      icon: "\u{f0026}"
      label: "No GitLab yet"
      sublabel: "add one below -- glab auth login"
      enabled: false
    }

    PanelSection {
      title: "GitLab"
      rule: true
    }

    PanelRow {
      icon: "\u{f0450}"
      label: "Check now"
      sublabel: "asks every GitLab, rather than at the next minute"
      enabled: !checkNow.running
      onClicked: checkNow.running = true
    }

    PanelRow {
      icon: "\u{f0415}"
      label: "Add a GitLab"
      sublabel: "glab auth login, in a terminal  ·  shows here at the next check"
      onClicked: {
        root.close();
        Quickshell.execDetached({
          command: ["desktop-launch-floating-terminal-with-presentation", "glab", "auth", "login"],
          workingDirectory: Quickshell.env("HOME")
        });
      }
    }
  }
}
