import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui

// Application launcher, in place of `desktop-menu apps` shelling out to wofi.
//
// Quickshell's DesktopEntries has already read and parsed the .desktop files, argv and
// all, so this is a matcher and a list rather than a parser. It exists mostly because
// the panels already proved the pieces -- a layer surface that takes the keyboard, a
// text field, a list with a cursor.
Item {
  id: root

  // The `launcher` subtree of shell.json.
  property var config: ({})

  // Not `width`: final on Item, and shadowing it fails the whole config load.
  readonly property int surfaceWidth: (config && config.width) ? config.width : 520
  readonly property int maxResults: (config && config.maxResults) ? config.maxResults : 8

  property bool open: false
  property string query: ""
  property int cursor: 0

  readonly property var entries: DesktopEntries.applications ? DesktopEntries.applications.values : []

  // Ranked rather than merely filtered: a prefix of the name is what you meant, a
  // substring of it is probably what you meant, and a keyword match is a guess.
  function score(entry, needle) {
    if (entry.noDisplay)
      return -1;

    var name = (entry.name || "").toLowerCase();
    if (needle === "")
      return 1;

    if (name.indexOf(needle) === 0)
      return 100 - name.length * 0.01;
    if (name.indexOf(needle) !== -1)
      return 60 - name.length * 0.01;

    var generic = (entry.genericName || "").toLowerCase();
    if (generic.indexOf(needle) !== -1)
      return 40;

    var keywords = entry.keywords || [];
    for (var i = 0; i < keywords.length; i++)
      if (String(keywords[i]).toLowerCase().indexOf(needle) !== -1)
        return 20;

    var exec = (entry.execString || "").toLowerCase();
    if (exec.indexOf(needle) !== -1)
      return 10;

    return -1;
  }

  readonly property var results: {
    var needle = query.trim().toLowerCase();
    var scored = [];
    for (var i = 0; i < entries.length; i++) {
      var value = score(entries[i], needle);
      if (value >= 0)
        scored.push({
          entry: entries[i],
          score: value
        });
    }

    scored.sort(function (a, b) {
      if (a.score !== b.score)
        return b.score - a.score;
      return (a.entry.name || "").localeCompare(b.entry.name || "");
    });

    var out = [];
    for (var j = 0; j < scored.length && j < root.maxResults; j++)
      out.push(scored[j].entry);
    return out;
  }

  function show() {
    query = "";
    cursor = 0;
    open = true;
    // The field only exists while the surface does, so focus has to wait for it -- and
    // its text has to be cleared with the query, or a reopened launcher shows the last
    // search over a list of everything.
    Qt.callLater(function () {
      if (!root.field)
        return;
      root.field.text = "";
      root.field.take();
    });
  }

  function hide() {
    open = false;
    query = "";
  }

  function toggle() {
    if (open)
      hide();
    else
      show();
    return open;
  }

  function launch(entry) {
    if (!entry)
      return;
    hide();

    // uwsm scopes the app to its own systemd unit, the way every other launcher in
    // this checkout does it. runInTerminal entries get the terminal wrapped around
    // them, since nothing else will.
    var command = entry.runInTerminal ? ["uwsm", "app", "--", "alacritty", "-e"].concat(entry.command) : ["uwsm", "app", "--"].concat(entry.command);

    Quickshell.execDetached({
      command: command,
      workingDirectory: entry.workingDirectory !== "" ? entry.workingDirectory : Quickshell.env("HOME")
    });
  }

  function moveCursor(delta) {
    var count = results.length;
    if (count === 0) {
      cursor = 0;
      return;
    }
    cursor = (cursor + delta + count) % count;
  }

  property var field: null

  // Click-outside, the same trick PopupHost uses: a transparent window under the
  // launcher, one per screen so a click on any monitor closes it.
  Variants {
    model: Quickshell.screens

    delegate: Component {
      PanelWindow {
        required property var modelData

        screen: modelData
        visible: root.open
        color: "transparent"

        WlrLayershell.namespace: "desktop-launcher-catcher"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: 0

        MouseArea {
          anchors.fill: parent
          onPressed: root.hide()
        }
      }
    }
  }

  ScreenSurface {
    id: surface

    visible: root.open
    position: "center"
    focusable: true
    interactive: true
    surfaceNamespace: "desktop-launcher"

    Rectangle {
      width: root.surfaceWidth
      height: layout.implicitHeight + Style.popupPadding * 2
      radius: Style.radius
      color: Color.popupBackground
      border.width: 1
      border.color: Color.popupBorder

      Column {
        id: layout

        anchors.fill: parent
        anchors.margins: Style.popupPadding
        spacing: 6

        PanelInput {
          id: input

          width: parent.width
          placeholder: "Search applications"

          Component.onCompleted: root.field = input

          onTextChanged: {
            root.query = text;
            root.cursor = 0;
          }
          onAccepted: root.launch(root.results[root.cursor])
          onCancelled: root.hide()

          // Arrows have to be caught here: the field owns the keyboard while it has
          // focus, and taking focus away from it to move a cursor would stop typing.
          Keys.onUpPressed: event => {
            root.moveCursor(-1);
            event.accepted = true;
          }
          Keys.onDownPressed: event => {
            root.moveCursor(1);
            event.accepted = true;
          }
        }

        Column {
          width: parent.width
          spacing: Style.rowSpacing

          Repeater {
            model: root.results

            delegate: PanelRow {
              required property var modelData
              required property int index

              iconSource: modelData.icon ? Quickshell.iconPath(modelData.icon, true) : ""
              label: modelData.name || ""
              sublabel: modelData.genericName || modelData.comment || ""
              cursor: root.cursor === index
              onClicked: root.launch(modelData)
            }
          }
        }

        Text {
          width: parent.width
          visible: root.results.length === 0
          text: "No match"
          color: Color.popupMuted
          font.family: Style.fontFamily
          font.pixelSize: Style.fontSize
          horizontalAlignment: Text.AlignHCenter
        }
      }
    }
  }
}
