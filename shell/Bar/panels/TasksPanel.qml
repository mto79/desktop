import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Tasks: every change that has a worktree of its own, in every repository.
//
// A task is a branch, a directory beside its repository and usually an agent working in
// it -- and nothing listed them together. `desktop-worktree list` answers for the
// repository you are standing in; with three repositories on the go that is three places
// to ask, and the one that has been finished since Tuesday and never pushed is in none of
// the places you look. Here they are in one list: how far each has got, whether anything
// in it is uncommitted, and what its agent is doing.
//
// The numbers are desktop-worktree's own (tasks --json), so this cannot disagree with it.
Popup {
  id: root

  readonly property string panelId: "tasks"

  property var groups: []
  property int total: 0
  property int waiting: 0
  property bool loaded: false

  function apply(text) {
    var tasks = [];
    try {
      tasks = JSON.parse(text).tasks || [];
    } catch (error) {
      tasks = [];
    }
    var byRepo = {};
    var order = [];
    var held = 0;
    for (var i = 0; i < tasks.length; i++) {
      var repo = tasks[i].repo;
      if (byRepo[repo] === undefined) {
        byRepo[repo] = [];
        order.push(repo);
      }
      byRepo[repo].push(tasks[i]);
      if (tasks[i].state === "waiting")
        held++;
    }
    var out = [];
    for (var g = 0; g < order.length; g++)
      out.push({
        repo: order[g],
        tasks: byRepo[order[g]]
      });
    groups = out;
    total = tasks.length;
    waiting = held;
    loaded = true;
  }

  Process {
    id: probe

    command: ["desktop-worktree", "tasks", "--json"]

    stdout: StdioCollector {
      onStreamFinished: root.apply(text)
    }
  }

  function refresh() {
    if (!probe.running)
      probe.running = true;
  }

  onVisibleChanged: if (visible)
    refresh()

  // Only while it is being looked at: every refresh asks git about every task.
  Timer {
    interval: 10000
    repeat: true
    running: root.visible
    onTriggered: root.refresh()
  }

  function glyph(task) {
    if (task.state === "waiting")
      return "\u{f0026}";
    if (task.state === "done")
      return "\u{f012c}";
    if (task.state === "working")
      return "\u{f06a9}";
    return task.open ? "\u{f062c}" : "\u{f0256}";
  }

  function detail(task) {
    var parts = [];
    parts.push(task.ahead === 0 ? "nothing committed yet" : task.ahead + (task.ahead === 1 ? " commit" : " commits"));
    if (task.dirty > 0)
      parts.push(task.dirty + " uncommitted");
    if (task.state === "waiting")
      parts.push("waiting for you");
    else if (task.state === "working")
      parts.push("working");
    else if (task.state === "done")
      parts.push("finished its turn");
    else if (!task.open)
      parts.push("not open");
    return parts.join("  ·  ");
  }

  // Not named open or close: those are the panel's own.
  //
  // To the tab or window the task is in. One that has neither -- left behind by a reboot
  // or a closed window -- is given a window first, and is somewhere to go the next time.
  function goTo(task) {
    if (task.target !== "") {
      Quickshell.execDetached(["desktop-menu-agents", "--jump", task.target]);
      root.close();
      return;
    }
    Quickshell.execDetached(["env", "DESKTOP_WORKTREE_NO_SWITCH=1", "desktop-worktree", "open", task.path]);
    reopen.restart();
  }

  Timer {
    id: reopen

    interval: 1500
    onTriggered: root.refresh()
  }

  // "done" has things to say and a question to ask, so it gets a terminal of its own:
  // what it will push and remove, then y or n, then the address of the review.
  function finish(task) {
    Quickshell.execDetached(["uwsm", "app", "--", "ghostty", "--title=Desktop", "-e", "bash", "-c", "cd \"$1\" && desktop-worktree done --ask; echo; read -r -n 1 -s -p 'press a key'", "finish", task.path]);
    root.close();
  }

  contentHeight: column.implicitHeight + Style.popupPadding * 2

  Column {
    id: column

    width: parent.width
    spacing: 2

    PanelHero {
      icon: "\u{f062c}"
      iconColor: root.waiting > 0 ? Color.popupUrgent : (root.total > 0 ? Color.popupAccent : Color.popupText)
      title: "Tasks"
      status: {
        if (!root.loaded)
          return "Looking";
        if (root.total === 0)
          return "None";
        var text = root.total === 1 ? "1 task" : root.total + " tasks";
        return root.waiting > 0 ? text + "  ·  " + root.waiting + " waiting for you" : text;
      }
      value: root.total > 0 ? String(root.total) : ""
    }

    Text {
      width: parent.width
      visible: root.loaded && root.total === 0
      topPadding: Style.sectionSpacing
      wrapMode: Text.WordWrap
      text: "A task is a change with a worktree of its own.\nprefix + T in tmux starts one."
      color: Color.popupMuted
      font.family: Style.fontFamily
      font.pixelSize: Style.fontSize
      horizontalAlignment: Text.AlignHCenter
    }

    Flickable {
      id: list

      width: parent.width
      height: Math.min(contentHeight, Style.rowHeight * 9)
      contentHeight: entries.implicitHeight
      visible: root.total > 0
      clip: true
      boundsBehavior: Flickable.StopAtBounds

      Column {
        id: entries

        width: list.width

        Repeater {
          model: root.groups

          delegate: Column {
            id: group

            required property var modelData

            width: entries.width

            PanelSection {
              title: group.modelData.repo
              value: group.modelData.tasks.length > 1 ? String(group.modelData.tasks.length) : ""
              rule: true
            }

            Repeater {
              model: group.modelData.tasks

              delegate: PanelRow {
                required property var modelData

                icon: root.glyph(modelData)
                accentColor: modelData.state === "waiting" ? Color.popupUrgent : Color.popupAccent
                active: modelData.state === "waiting" || modelData.state === "done"
                label: modelData.name
                sublabel: root.detail(modelData)

                onClicked: root.goTo(modelData)
                // Finishing pushes and removes. It stays on the right button, and asks.
                onRightClicked: root.finish(modelData)
              }
            }
          }
        }
      }
    }

    Text {
      width: parent.width
      visible: root.total > 0
      topPadding: Style.sectionSpacing
      text: "Click goes there  ·  right click finishes it"
      color: Color.popupMuted
      font.family: Style.fontFamily
      font.pixelSize: Style.fontSize - 2
      horizontalAlignment: Text.AlignHCenter
    }
  }
}
