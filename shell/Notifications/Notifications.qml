import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.Commons
import qs.Ui

// Notification toasts, in place of mako.
//
// Only one process can own org.freedesktop.Notifications, so this and mako are
// mutually exclusive: mako is out of the Hyprland autostart, and the shell's own
// supervisor starts it again if Quickshell will not stay up (see desktop-launch-shell).
//
// A notification is discarded unless it is tracked, so the server hands each one to
// trackedNotifications and the stack below renders that model.
Item {
  id: root

  // The `notifications` subtree of shell.json.
  property var config: ({})

  readonly property string position: (config && config.position) ? config.position : "top-right"
  readonly property int margin: (config && config.margin) ? config.margin : 12
  // Not `width`: that is final on Item, and shadowing it fails the whole config load.
  readonly property int toastWidth: (config && config.width) ? config.width : 380
  readonly property int maxVisible: (config && config.maxVisible) ? config.maxVisible : 5
  // The toasts' base text size, and everything in them is sized from it. A step above
  // the shell's 13, which panels are laid out around: a toast is read in a glance from
  // wherever you were looking, not studied. Overridable with notifications.fontSize.
  readonly property int fontSize: (config && config.fontSize) ? config.fontSize : Style.fontSize + 2

  // Per-urgency defaults, used when the sender does not say. Critical stays up until
  // it is dismissed, which is the one convention every notification daemon agrees on.
  readonly property var timeouts: ({
      low: (config && config.timeoutLow) ? config.timeoutLow : 4000,
      normal: (config && config.timeoutNormal) ? config.timeoutNormal : 6000,
      critical: (config && config.timeoutCritical !== undefined) ? config.timeoutCritical : 0
    })

  function defaultTimeout(urgency) {
    if (urgency === NotificationUrgency.Critical)
      return timeouts.critical;
    if (urgency === NotificationUrgency.Low)
      return timeouts.low;
    return timeouts.normal;
  }

  // The spec's expire_timeout is milliseconds and Quickshell reports seconds, so a
  // value that looks like milliseconds is treated as such rather than parking a toast
  // on screen for an hour and a half.
  function timeoutFor(notification) {
    var given = notification.expireTimeout;
    if (given === undefined || given < 0)
      return defaultTimeout(notification.urgency);
    if (given === 0)
      return 0;
    return given < 1000 ? given * 1000 : given;
  }

  function accent(urgency) {
    if (urgency === NotificationUrgency.Critical)
      return Color.popupUrgent;
    if (urgency === NotificationUrgency.Low)
      return Color.popupMuted;
    return Color.popupAccent;
  }

  NotificationServer {
    id: server

    // Everything the toast below can actually render is declared; claiming more would
    // have senders send markup and images this never draws.
    keepOnReload: false
    bodySupported: true
    bodyMarkupSupported: true
    actionsSupported: true
    imageSupported: true
    persistenceSupported: true

    onNotification: notification => {
      // Untracked notifications are dropped the moment this handler returns.
      notification.tracked = true;
      Inbox.noteArrival(notification.id);
      root.trim();
    }
  }

  // The list the bell and the notification centre read. See Inbox.
  Binding {
    target: Inbox
    property: "all"
    value: server.trackedNotifications ? server.trackedNotifications.values : []
  }

  // A toast that has had its time is put away, not thrown away: it leaves the screen and
  // stays in the notification centre, still the live notification, until it is dealt
  // with there. Reassigned rather than changed in place, so the stack below notices.
  property var retired: ({})

  // Asked for by a toast's own timer, and done a moment later from out here. Retiring
  // changes the list the stack is drawn from, which destroys the toast that asked: doing
  // that from inside that toast's handler crashed the shell the first time several timed
  // out in the same instant. So a toast only says it is done, and this works through
  // everything that said so, in one change.
  property var retiring: []

  function retire(notification) {
    retiring.push(notification);
    sweep.restart();
  }

  Timer {
    id: sweep

    interval: 20
    onTriggered: {
      var due = root.retiring;
      root.retiring = [];
      var next = {};
      var all = server.trackedNotifications ? server.trackedNotifications.values : [];
      for (var i = 0; i < all.length; i++)
        if (root.retired[all[i].id])
          next[all[i].id] = true;
      var forget = [];
      for (var d = 0; d < due.length; d++) {
        if (!due[d])
          continue;
        // Asked to be forgotten by its own sender -- a volume step, a progress tick.
        // Keeping those would fill the centre with things never meant to be read twice.
        if (due[d].transient)
          forget.push(due[d]);
        else
          next[due[d].id] = true;
      }
      root.retired = next;
      for (var f = 0; f < forget.length; f++)
        forget[f].expire();
    }
  }

  // What was held back while do-not-disturb was on does not all arrive at once when it
  // goes off: that would be the interruption it was turned on to avoid, only later and
  // all together. It is in the notification centre, where the bell counts it.
  onDoNotDisturbChanged: if (!doNotDisturb) {
    var next = {};
    var all = server.trackedNotifications ? server.trackedNotifications.values : [];
    for (var i = 0; i < all.length; i++)
      next[all[i].id] = true;
    retired = next;
  }

  // Kept is not kept for ever. Past this many the oldest that has left the screen goes,
  // so a chatty application over a long day cannot grow the list without end.
  readonly property int keep: (config && config.keep) ? config.keep : 50

  function trim() {
    var all = server.trackedNotifications ? server.trackedNotifications.values.slice() : [];
    for (var i = 0; i < all.length && all.length - i > keep; i++)
      if (retired[all[i].id])
        all[i].expire();
  }

  // Likewise not `visible`.
  readonly property var showing: {
    if (doNotDisturb)
      return [];
    var all = server.trackedNotifications ? server.trackedNotifications.values : [];
    // Newest first, and never more than the stack is allowed to show.
    var out = [];
    for (var i = all.length - 1; i >= 0 && out.length < root.maxVisible; i--)
      if (!retired[all[i].id])
        out.push(all[i]);
    return out;
  }

  // Silenced notifications are still received and tracked -- nothing is lost, it just
  // does not interrupt. The switch itself is Inbox's, where the bell and the panel can
  // reach it and where it can end by itself.
  readonly property bool doNotDisturb: Inbox.doNotDisturb

  // Which notifications have already been drawn once. The stack is rebuilt from scratch
  // whenever the list changes -- its model is an array -- so every toast in it is a new
  // object each time, and without this each arrival would make all of them arrive again.
  // A plain object on purpose: nothing may bind to it, or noting an arrival would itself
  // be a change.
  readonly property var arrived: ({})

  function arriving(notification) {
    if (arrived[notification.id])
      return false;
    arrived[notification.id] = true;
    return true;
  }

  function toggleDnd() {
    return Inbox.toggleQuiet();
  }

  // Reached over IPC, since the toasts are dismissed with the mouse otherwise.
  function dismissLatest() {
    if (showing.length > 0)
      showing[0].dismiss();
  }

  function dismissAll() {
    var all = server.trackedNotifications ? server.trackedNotifications.values.slice() : [];
    for (var i = 0; i < all.length; i++)
      all[i].dismiss();
  }

  Variants {
    model: Quickshell.screens

    delegate: Component {
      ScreenSurface {
        required property var modelData

        screen: modelData
        surfaceNamespace: "desktop-notifications"
        visible: root.showing.length > 0
        position: root.position
        margin: root.margin
        interactive: true

        Column {
          spacing: 8

          Repeater {
            model: root.showing

            delegate: Toast {
              required property var modelData

              notification: modelData
            }
          }
        }
      }
    }
  }

  component Toast: Rectangle {
    id: toast

    required property var notification

    readonly property color accentColor: root.accent(notification.urgency)
    readonly property int timeout: root.timeoutFor(notification)

    // Chromium names itself, not the site. A Mattermost message arrives as
    //
    //   app_name "Brave"  summary "Direct Message"
    //   body     "chat.nationaalarchief.nl\n\n@ivo: ..."
    //
    // so the header read "Brave" for every tab that has ever asked for permission, and
    // the one thing identifying the sender was buried in the first line of the body.
    // Lift it out: the origin becomes the sender, and the body keeps only the message.
    readonly property bool fromBrowser: {
      var entry = String(notification.desktopEntry || "").toLowerCase();
      return entry.indexOf("brave") !== -1 || entry.indexOf("chrom") !== -1 || entry.indexOf("firefox") !== -1;
    }

    // Split only on something that looks like a host: one line, no spaces, at least one
    // dot, followed by a blank line. A body that merely opens with a short sentence is
    // left alone.
    readonly property var originSplit: {
      if (!fromBrowser)
        return null;
      var body = String(notification.body || "");
      var brk = body.indexOf("\n\n");
      if (brk <= 0)
        return null;
      var head = body.slice(0, brk).trim();
      if (head === "" || head.indexOf(" ") !== -1 || head.indexOf(".") === -1)
        return null;
      return {
        origin: head,
        rest: body.slice(brk + 2).trim()
      };
    }

    // notify-send reports itself as the app unless it is given --app-name, and no desktop-*
    // script gives one, so the header over most toasts read "notify-send". A sender that
    // only names the tool it came through says nothing; leave the line out and let the
    // title lead.
    readonly property string senderLabel: {
      if (originSplit)
        return originSplit.origin;
      var app = String(notification.appName || "");
      return app === "notify-send" ? "" : app;
    }
    readonly property string bodyText: originSplit ? originSplit.rest : notification.body

    // The actions worth a button. "default" is the whole-toast click, not a button of its
    // own. And Chromium hangs a "settings" action on every web notification, whatever the
    // site sent, so each chat message carried a Settings button that opened Brave's
    // notification preferences -- a site sends its own buttons as other identifiers.
    readonly property var buttons: {
      var out = [];
      var actions = notification.actions;
      for (var i = 0; i < actions.length; i++) {
        var id = actions[i].identifier;
        if (id === "default" || (fromBrowser && id === "settings"))
          continue;
        out.push(actions[i]);
      }
      return out;
    }
    // Whitespace collapsed: desktop-toggle-nightlight follows its icon glyph with three
    // spaces, which set that title visibly further right than every other one.
    readonly property string summaryText: String(notification.summary || "").replace(/\s+/g, " ").trim()

    width: root.toastWidth
    height: layout.implicitHeight + 24
    radius: Style.radius
    color: Color.popupBackground
    border.width: 1
    border.color: hover.containsMouse ? toast.accentColor : Color.popupBorder

    // In from the edge of the screen it sits against, the first time it is drawn. A
    // transform rather than x: the column owns where its children are.
    readonly property int travelFrom: (root.position.indexOf("left") !== -1 ? -1 : 1) * Style.motionTravel

    transform: Translate {
      id: travel
    }

    ParallelAnimation {
      id: arrival

      NumberAnimation {
        target: travel
        property: "x"
        from: toast.travelFrom
        to: 0
        duration: Style.motionEnter
        easing.type: Easing.OutCubic
      }
      NumberAnimation {
        target: toast
        property: "opacity"
        from: 0
        to: 1
        duration: Style.motionEnter
        easing.type: Easing.OutCubic
      }
    }

    Component.onCompleted: {
      remainingMs = timeLeft();
      if (root.arriving(notification))
        arrival.start();
    }

    // Critical notifications get no timer at all, so a zero timeout cannot be read as
    // "expire immediately".
    // How much of its time is left, worked out once when the toast is drawn. From when
    // the notification arrived, not from now: the stack is rebuilt whenever another toast
    // comes or goes, and counting from the rebuild gave every toast still on screen its
    // whole timeout again -- four that arrived together took four timeouts to clear.
    property int remainingMs: 0

    function timeLeft() {
      if (toast.timeout <= 0)
        return 0;
      var at = Inbox.arrivedAt[notification.id];
      if (at === undefined)
        return toast.timeout;
      return Math.max(1, Math.min(toast.timeout, at + toast.timeout - Date.now()));
    }

    Timer {
      interval: Math.max(1, toast.remainingMs)
      running: toast.timeout > 0 && toast.remainingMs > 0
      onTriggered: root.retire(toast.notification)
    }

    // How long it has left, as a line along the bottom that runs out. It shares the
    // timer's lifetime -- both start when the toast is drawn -- so the two cannot disagree.
    Rectangle {
      visible: toast.timeout > 0
      anchors.left: parent.left
      anchors.leftMargin: Style.radius
      anchors.bottom: parent.bottom
      anchors.bottomMargin: toast.border.width
      height: Style.barWorkspaceIndicatorHeight
      radius: height / 2
      color: toast.accentColor
      opacity: 0.6
      z: 1

      NumberAnimation on width {
        running: toast.timeout > 0 && toast.remainingMs > 0
        from: (toast.width - Style.radius * 2) * toast.remainingMs / Math.max(1, toast.timeout)
        to: 0
        duration: Math.max(1, toast.remainingMs)
      }
    }

    // A stripe rather than a tinted background: the urgency has to be legible without
    // making the text harder to read. It runs along the top edge and follows the rounded
    // corners: a rounded rectangle in the accent colour, with the background laid square
    // over all but its top few pixels. A 3px-tall rectangle cannot do it alone -- Qt
    // clamps a radius to half the height, so its corners would poke out past the curve.
    Rectangle {
      id: stripe

      readonly property int thickness: 3

      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: toast.border.width
      height: Math.max(Style.radius, thickness) * 2
      radius: Math.max(0, Style.radius - toast.border.width)
      color: toast.accentColor
    }

    Rectangle {
      anchors.left: stripe.left
      anchors.right: stripe.right
      anchors.top: stripe.top
      anchors.topMargin: stripe.thickness
      height: stripe.height
      color: toast.color
    }

    MouseArea {
      id: hover

      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      // Left click runs the default action when there is one -- clicking a chat
      // notification should open the chat -- and otherwise just gets rid of it. Right
      // click always dismisses.
      onClicked: mouse => {
        if (mouse.button === Qt.RightButton) {
          toast.notification.dismiss();
          return;
        }
        var actions = toast.notification.actions;
        for (var i = 0; i < actions.length; i++) {
          if (actions[i].identifier === "default") {
            actions[i].invoke();
            return;
          }
        }
        toast.notification.dismiss();
      }
    }

    Column {
      id: layout

      // Even on both sides now that the stripe is along the top, and nudged down by about
      // the stripe so the text sits centred in what is left under it.
      anchors.left: parent.left
      anchors.leftMargin: 14
      anchors.right: parent.right
      anchors.rightMargin: 14
      anchors.verticalCenter: parent.verticalCenter
      anchors.verticalCenterOffset: 2
      spacing: 3

      Text {
        width: parent.width
        visible: toast.senderLabel !== ""
        text: toast.senderLabel
        color: toast.accentColor
        font.family: Style.fontFamily
        font.pixelSize: root.fontSize - 2
        font.bold: true
        elide: Text.ElideRight
      }

      Text {
        width: parent.width
        visible: toast.summaryText !== ""
        text: toast.summaryText
        textFormat: Text.PlainText
        color: Color.popupText
        font.family: Style.fontFamily
        font.pixelSize: root.fontSize
        font.bold: true
        wrapMode: Text.WordWrap
        maximumLineCount: 2
        elide: Text.ElideRight
      }

      Text {
        width: parent.width
        visible: toast.bodyText !== ""
        text: toast.bodyText
        // Senders may send Pango markup; StyledText renders the subset Qt knows and
        // ignores the rest, which beats printing tags at the reader.
        textFormat: Text.StyledText
        color: Color.popupMuted
        font.family: Style.fontFamily
        font.pixelSize: root.fontSize - 1
        wrapMode: Text.WordWrap
        maximumLineCount: 6
        elide: Text.ElideRight
      }

      Row {
        spacing: 8
        visible: toast.buttons.length > 0
        topPadding: 4

        Repeater {
          model: toast.buttons

          delegate: Rectangle {
            required property var modelData

            width: actionLabel.implicitWidth + 18
            height: actionLabel.implicitHeight + 10
            radius: Style.radius
            color: actionMouse.containsMouse ? Color.popupHover : "transparent"
            border.width: 1
            border.color: Color.popupBorder

            Text {
              id: actionLabel

              anchors.centerIn: parent
              text: modelData.text || modelData.identifier
              color: Color.popupText
              font.family: Style.fontFamily
              font.pixelSize: root.fontSize - 2
            }

            MouseArea {
              id: actionMouse

              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: modelData.invoke()
            }
          }
        }
      }
    }
  }
}
