import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.Commons
import qs.Ui
import "../../Notifications/kept.js" as Kept

// Notification centre: what arrived while you were looking elsewhere.
//
// A toast is six seconds long. This is where it goes afterwards -- kept until it is dealt
// with, under who sent it: the application, or for a web app the site. Under that, one row
// a conversation: a chat's forty messages are one line with its newest and how many there
// are, not forty lines. The entries are the notifications themselves
// and not copies of their text: clicking one is the same click the toast offered, so a
// message still opens its chat and a finished build still opens its log, and dismissing
// one tells the sender so.
//
// Do-not-disturb is here too, with an end: on for an hour is the version that does not
// leave tomorrow's notifications silenced.
Popup {
  id: root

  readonly property string panelId: "notifications"

  // What is drawn, behind a short timer rather than bound to the list itself. Dismissing
  // an entry changes the list from inside one of its own rows, and a Repeater rebuilt
  // from within its own delegate's handler crashes.
  property var groups: []
  property int total: 0
  // Ticks while the panel is open, so "5m" becomes "6m".
  property double now: Date.now()


  // One list of both kinds: the notifications still alive, and the text of those kept from
  // before the shell last stopped. A row is told which it has by `live`.
  function rebuild() {
    var rowsNewestFirst = [];
    var all = Inbox.all;
    for (var i = all.length - 1; i >= 0; i--)
      rowsNewestFirst.push({
        live: true,
        notification: all[i],
        app: Kept.sender(all[i].appName, all[i].body, Kept.browser(all[i].desktopEntry)),
        key: Kept.thread(all[i].appName, all[i].summary, all[i].body, Kept.browser(all[i].desktopEntry)),
        summary: all[i].summary,
        body: all[i].body,
        critical: all[i].urgency === NotificationUrgency.Critical,
        at: Inbox.arrivedAt[all[i].id]
      });
    var past = Inbox.past;
    for (var p = past.length - 1; p >= 0; p--)
      rowsNewestFirst.push({
        live: false,
        entry: past[p],
        // The browser is known only by name here: what was written down is the app's name.
        app: Kept.sender(past[p].app, past[p].body, Kept.browser(past[p].app)),
        key: Kept.thread(past[p].app, past[p].summary, past[p].body, Kept.browser(past[p].app)),
        summary: past[p].summary,
        body: past[p].body,
        critical: past[p].critical === true,
        at: past[p].at
      });

    var byApp = {};
    var order = [];
    // An application is as recent as its newest.
    for (var r = 0; r < rowsNewestFirst.length; r++) {
      var app = rowsNewestFirst[r].app;
      if (byApp[app] === undefined) {
        byApp[app] = [];
        order.push(app);
      }
      byApp[app].push(rowsNewestFirst[r]);
    }
    var out = [];
    for (var g = 0; g < order.length; g++)
      out.push({
        app: order[g],
        count: byApp[order[g]].length,
        threads: Kept.threads(byApp[order[g]])
      });
    groups = out;
    total = rowsNewestFirst.length;
  }

  Timer {
    id: settle

    interval: 60
    onTriggered: root.rebuild()
  }

  Connections {
    target: Inbox

    function onAllChanged() {
      settle.restart();
    }
    function onPastChanged() {
      settle.restart();
    }
  }

  onVisibleChanged: if (visible) {
    now = Date.now();
    rebuild();
  }

  Timer {
    interval: 30000
    repeat: true
    running: root.visible
    onTriggered: root.now = Date.now()
  }

  function ago(at) {
    if (at === undefined || at === null)
      return "";
    var minutes = Math.floor((now - at) / 60000);
    if (minutes < 1)
      return "now";
    if (minutes < 60)
      return minutes + "m";
    var hours = Math.floor(minutes / 60);
    return hours < 24 ? hours + "h" : Math.floor(hours / 24) + "d";
  }

  function oneLine(text) {
    return String(text || "").replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim();
  }

  // Later, not now: both of these change the list the row asking is part of.
  //
  // Not named open and close: those are the panel's own, and a function called open here
  // replaced the one that shows it -- the panel then did nothing at all when asked for.
  function follow(row) {
    // Kept from before: there is nobody left to tell, so reading it is all there is.
    if (!row.live) {
      putAway(row);
      return;
    }
    var notification = row.notification;
    Qt.callLater(function () {
      var actions = notification.actions;
      for (var i = 0; i < actions.length; i++)
        if (actions[i].identifier === "default") {
          actions[i].invoke();
          root.close();
          return;
        }
      notification.dismiss();
    });
  }

  function putAway(row) {
    Qt.callLater(function () {
      if (row.live)
        row.notification.dismiss();
      else
        Inbox.forget(row.entry);
    });
  }

  // A whole conversation at once: what a right click on its row does.
  function putAwayAll(rows) {
    for (var i = 0; i < rows.length; i++)
      putAway(rows[i]);
  }

  // The body without a browser's site on its first line: the toast lifted it into the
  // header, and here it is the section's title already.
  function message(row) {
    var split = Kept.originSplit(row.body);
    return oneLine(split ? split.rest : row.body);
  }

  function clearAll() {
    var all = Inbox.all.slice();
    Qt.callLater(function () {
      for (var i = 0; i < all.length; i++)
        all[i].dismiss();
      Inbox.forgetAll();
    });
  }

  readonly property string quietText: {
    if (!Inbox.doNotDisturb)
      return "New ones appear as they arrive";
    if (Inbox.quietUntil <= 0)
      return "Held back until you turn this off";
    var minutes = Math.max(1, Math.ceil((Inbox.quietUntil - now) / 60000));
    return "Held back for another " + (minutes >= 60 ? Math.round(minutes / 60) + "h" : minutes + "m");
  }

  contentHeight: column.implicitHeight + Style.popupPadding * 2

  Column {
    id: column

    width: parent.width
    spacing: 2

    PanelHero {
      icon: Inbox.doNotDisturb ? "\u{f009b}" : "\u{f009a}"
      iconColor: Inbox.doNotDisturb ? Color.popupMuted : (root.total > 0 ? Color.popupAccent : Color.popupText)
      title: "Notifications"
      status: root.total === 0 ? "Nothing waiting" : (root.total === 1 ? "1 kept" : root.total + " kept")
      value: root.total > 0 ? String(root.total) : ""
    }

    PanelRow {
      icon: "\u{f009b}"
      label: "Do not disturb"
      sublabel: root.quietText
      active: Inbox.doNotDisturb
      onClicked: Inbox.toggleQuiet()
    }

    PanelRow {
      visible: !Inbox.doNotDisturb || Inbox.quietUntil <= 0
      icon: "\u{f051b}"
      label: "Do not disturb for an hour"
      sublabel: "Turns itself off again"
      onClicked: {
        Inbox.quiet(60);
        root.now = Date.now();
      }
    }

    PanelRow {
      visible: root.total > 0
      icon: "\u{f0a7a}"
      label: "Clear all"
      sublabel: "Dismiss every notification below"
      onClicked: root.clearAll()
    }

    // Eight rows then scroll: a morning's worth must not grow into a full-screen list.
    Flickable {
      id: list

      width: parent.width
      height: Math.min(contentHeight, Style.rowHeight * 8)
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
              title: group.modelData.app
              value: group.modelData.count > 1 ? String(group.modelData.count) : ""
              rule: true
            }

            Repeater {
              model: group.modelData.threads

              delegate: PanelRow {
                id: row

                required property var modelData

                readonly property var newest: modelData.newest
                readonly property int many: modelData.rows.length
                readonly property bool critical: newest.critical

                icon: critical ? "\u{f0026}" : (many > 1 ? "\u{f0369}" : "\u{f0f6a}")
                accentColor: critical ? Color.popupUrgent : Color.popupAccent
                active: critical
                label: (root.oneLine(newest.summary) !== "" ? root.oneLine(newest.summary) : root.message(newest)) + (many > 1 ? "  ·  " + many : "")
                sublabel: root.oneLine(newest.summary) !== "" ? root.message(newest) : ""

                // Left is the newest message's own action, as on the toast -- it opens the
                // chat, where the rest are too, so they are put away with it. Right puts
                // the whole conversation away without opening it.
                onClicked: {
                  root.follow(newest);
                  root.putAwayAll(modelData.rows.slice(1));
                }
                onRightClicked: root.putAwayAll(modelData.rows)

                Text {
                  text: root.ago(row.newest.at)
                  color: Color.popupMuted
                  font.family: Style.fontFamily
                  font.pixelSize: Style.fontSize - 2
                }
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
      // Wrapped rather than cut: the panel is narrower than the sentence.
      wrapMode: Text.WordWrap
      text: "Click opens  ·  right click dismisses the conversation\nThose from before a restart can only be read"
      color: Color.popupMuted
      font.family: Style.fontFamily
      font.pixelSize: Style.fontSize - 2
      horizontalAlignment: Text.AlignHCenter
    }
  }
}
