import QtQuick
import Quickshell
import Quickshell.Io
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

  // Select mode: the same surface, driven by a list handed in over IPC. This is what
  // bin/desktop-menu-select uses, so the whole desktop-menu tree renders here instead
  // of in wofi -- one function in that script rather than a rewrite of its 22 submenus.
  property string resultFile: ""
  property string prompt: ""
  property var items: []
  // A caller may need a wider surface or more rows than the app list wants -- the
  // keybindings reference is two columns of text, not a list of names.
  property int selectWidth: 0
  property int selectRows: 0

  readonly property bool selecting: resultFile !== ""

  readonly property var entries: DesktopEntries.applications ? DesktopEntries.applications.values : []

  // An option is a plain line, or glyph/label/subtext separated by tabs. A plain line
  // comes back verbatim, because callers match on what they sent.
  function parseItem(line) {
    var fields = line.split("\t");
    if (fields.length === 1)
      return {
        glyph: "",
        label: line,
        sub: "",
        value: line
      };
    return {
      glyph: fields[0],
      label: fields[1] || "",
      sub: fields[2] || "",
      value: fields.length > 2 ? fields[1] + "\t" + fields[2] : (fields[1] || "")
    };
  }

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

  readonly property var itemResults: {
    var needle = query.trim().toLowerCase();
    var limit = selectRows > 0 ? selectRows : maxResults;
    var out = [];
    for (var i = 0; i < items.length && out.length < limit; i++) {
      var parsed = parseItem(items[i]);
      if (needle === "" || parsed.label.toLowerCase().indexOf(needle) !== -1 || parsed.sub.toLowerCase().indexOf(needle) !== -1)
        out.push(parsed);
    }
    return out;
  }

  readonly property var results: selecting ? itemResults : appResults

  readonly property var appResults: {
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
    // A caller blocked on the result file has to be answered even when the launcher
    // was dismissed: an empty selection is how cancellation is reported.
    if (selecting)
      answer("", false);
  }

  function showSelect(itemsText, resultPath, promptText, preselect) {
    var lines = itemsText.split("\n");
    var kept = [];
    for (var i = 0; i < lines.length; i++)
      if (lines[i] !== "")
        kept.push(lines[i]);

    items = kept;
    resultFile = resultPath;
    prompt = promptText;
    query = "";
    cursor = 0;

    open = true;
    Qt.callLater(function () {
      if (root.field) {
        root.field.text = "";
        root.field.take();
      }
      // After the clear, not before: emptying the field fires onTextChanged, which
      // resets the cursor -- so a preselect applied first was thrown away whenever the
      // field still held the previous menu's search.
      root.applyPreselect(preselect);
    });
  }

  // The preselect is a value, not an index: callers know which theme is current, not
  // where it sits in a list they did not order.
  function applyPreselect(value) {
    if (value === "")
      return;
    for (var i = 0; i < itemResults.length; i++)
      if (itemResults[i].value === value || itemResults[i].label === value) {
        cursor = i;
        return;
      }
  }

  // Reading the options from a file rather than an IPC argument: a menu can be long,
  // and quoting a whole list through an argv round trip is a bug waiting to happen.
  function selectFrom(itemsFile, resultPath, promptText, preselect, width, rows) {
    if (itemsFile === "" || resultPath === "")
      return false;

    // A second request while one is in flight has to cancel the first, or its caller
    // sits in its polling loop waiting for a file nobody is going to write. Both the
    // showing request and one still loading its options count.
    if (selecting)
      answer("", false);
    if (pendingResult !== "") {
      writeResult(pendingResult, "0\n");
      pendingResult = "";
    }

    pendingResult = resultPath;
    pendingPrompt = promptText;
    pendingPreselect = preselect;
    selectWidth = parseInt(width, 10) || 0;
    selectRows = parseInt(rows, 10) || 0;
    source.path = "";
    source.path = itemsFile;
    return true;
  }

  property string pendingResult: ""
  property string pendingPrompt: ""
  property string pendingPreselect: ""

  FileView {
    id: source

    onLoaded: {
      root.showSelect(text(), root.pendingResult, root.pendingPrompt, root.pendingPreselect);
      root.pendingResult = "";
    }

    onLoadFailed: {
      console.warn("Launcher: could not read options from", source.path);
      root.pendingResult = "";
    }
  }

  // The result file carries a status line before the value: "1" and the selection, or
  // "0" alone for a cancellation. Emptiness cannot carry that meaning -- setText("")
  // writes nothing at all, so a cancelled caller waited for a file that never appeared.
  function answer(value, chosen) {
    if (resultFile === "")
      return;
    writeResult(resultFile, chosen ? "1\n" + value : "0\n");
    resultFile = "";
    items = [];
    prompt = "";
    selectWidth = 0;
    selectRows = 0;
  }

  // Not FileView: assigning its path starts a read, and for a file that does not exist
  // yet -- which is every result file -- that read fails and takes the queued write
  // with it. A one-shot command writes to a temp name and renames, so the waiting
  // script sees the file complete or not at all, and the arguments travel as argv
  // rather than through a quoted string.
  function writeResult(path, payload) {
    Quickshell.execDetached({
      command: ["sh", "-c", 'printf "%s" "$1" > "$2.part" && mv "$2.part" "$2"', "desktop-shell-select", payload, path],
      workingDirectory: Quickshell.env("HOME")
    });
  }

  function choose(parsed) {
    open = false;
    query = "";
    answer(parsed ? parsed.value : "", parsed !== null && parsed !== undefined);
  }

  function toggle() {
    if (open)
      hide();
    else
      show();
    return open;
  }

  // Enter and click mean "take this row", whichever mode the surface is in.
  function activate(item) {
    if (root.selecting)
      choose(item);
    else
      launch(item);
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
      width: (root.selecting && root.selectWidth > 0) ? root.selectWidth : root.surfaceWidth
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
          placeholder: root.selecting ? root.prompt : "Search applications"

          Component.onCompleted: root.field = input

          onTextChanged: {
            root.query = text;
            root.cursor = 0;
          }
          onAccepted: root.activate(root.results[root.cursor])
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

              iconSource: (!root.selecting && modelData.icon) ? Quickshell.iconPath(modelData.icon, true) : ""
              icon: root.selecting ? modelData.glyph : ""
              label: root.selecting ? modelData.label : (modelData.name || "")
              sublabel: root.selecting ? modelData.sub : (modelData.genericName || modelData.comment || "")
              cursor: root.cursor === index
              onClicked: root.activate(modelData)
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
