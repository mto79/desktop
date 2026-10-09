import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "../Commons/calc.js" as Calc

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
  // Input mode is select mode with no list: the answer is what was typed rather than
  // which row was under the cursor.
  property bool inputMode: false

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

  readonly property var results: selecting ? itemResults : (mode === "apps" ? appResults : modeResults)

  // --- modes ---------------------------------------------------------------------------
  //
  // The launcher opens applications. A first character turns it into something else for
  // as long as it is there, so the other things worth one keystroke do not each need a
  // key of their own:
  //
  //   =  work something out      = 1920 / 1.6
  //   >  run a command           > systemctl --user restart pipewire
  //   /  go to a window          / firefox
  //   :  find an emoji           : rocket
  //   ?  list these
  //
  // Symbols on purpose: no application's name begins with one, so nothing typed to find
  // an application can land in a mode by accident.
  readonly property var modes: [
    {
      prefix: "=",
      name: "calc",
      glyph: "\u{f00ec}",
      label: "Calculate",
      sub: "= 1920 / 1.6  ·  Enter copies the answer"
    },
    {
      prefix: ">",
      name: "run",
      glyph: "\u{f018d}",
      label: "Run a command",
      sub: "> systemctl --user restart pipewire"
    },
    {
      prefix: "/",
      name: "windows",
      glyph: "\u{f05af}",
      label: "Go to a window",
      sub: "/ firefox  ·  every window on every workspace"
    },
    {
      prefix: ":",
      name: "emoji",
      glyph: "\u{f01f5}",
      label: "Find an emoji",
      sub: ": rocket  ·  Enter copies it"
    }
  ]

  readonly property string mode: {
    if (selecting || query === "")
      return "apps";
    var first = query.charAt(0);
    if (first === "?")
      return "help";
    for (var i = 0; i < modes.length; i++)
      if (modes[i].prefix === first)
        return modes[i].name;
    return "apps";
  }
  // What was typed after the prefix.
  readonly property string modeQuery: mode === "apps" ? "" : query.slice(1).trim()
  // Rows in a mode are the same shape as a menu's -- glyph, label, subtext -- with what
  // choosing one does added to it.
  readonly property bool listing: selecting || mode !== "apps"

  // Emoji, loaded the first time they are asked for and kept: 1800 lines are not worth
  // reading at every login for a mode that may not be used that day.
  property var emoji: []

  Process {
    id: emojiLoader

    command: ["desktop-emoji-list"]

    stdout: StdioCollector {
      onStreamFinished: {
        var out = [];
        var lines = text.split("\n");
        for (var i = 0; i < lines.length; i++) {
          var tab = lines[i].indexOf("\t");
          if (tab > 0)
            out.push({
              symbol: lines[i].slice(0, tab),
              name: lines[i].slice(tab + 1)
            });
        }
        root.emoji = out;
      }
    }
  }

  onModeChanged: {
    if (mode === "emoji" && emoji.length === 0 && !emojiLoader.running)
      emojiLoader.running = true;
    // Where a window is comes from Hyprland's last answer about it.
    if (mode === "windows")
      Hyprland.refreshToplevels();
  }

  // The sum itself is worked out in calc.js, which is kept free of QML so that the one
  // rule that matters about it -- arithmetic and nothing else -- can be tested.
  function calculate(text) {
    return Calc.calculate(text);
  }

  // Every word typed has to be in the text, in any order: "face tears" finds "face with
  // tears of joy".
  function matchesAll(text, needle) {
    var words = needle.toLowerCase().split(/\s+/);
    for (var i = 0; i < words.length; i++)
      if (words[i] !== "" && text.indexOf(words[i]) === -1)
        return false;
    return true;
  }

  readonly property var modeResults: {
    var out = [];
    var needle = modeQuery;

    if (mode === "help") {
      for (var m = 0; m < modes.length; m++)
        out.push({
          glyph: modes[m].glyph,
          label: modes[m].prefix + "  " + modes[m].label,
          sub: modes[m].sub,
          kind: "prefix",
          payload: modes[m].prefix + " "
        });
      return out;
    }

    if (mode === "calc") {
      var answer = calculate(needle);
      if (answer !== null)
        out.push({
          glyph: "\u{f00ec}",
          label: answer,
          sub: needle + "  ·  Enter copies the answer",
          kind: "copy",
          payload: answer
        });
      return out;
    }

    if (mode === "run") {
      if (needle === "")
        return out;
      out.push({
        glyph: "\u{f018d}",
        label: needle,
        sub: "Run it",
        kind: "run",
        payload: needle
      });
      out.push({
        glyph: "\u{f018d}",
        label: needle,
        sub: "Run it in a terminal, and keep the window to read what it said",
        kind: "terminal",
        payload: needle
      });
      return out;
    }

    if (mode === "windows") {
      var tops = Hyprland.toplevels ? Hyprland.toplevels.values : [];
      for (var t = 0; t < tops.length && out.length < maxResults; t++) {
        var ipc = tops[t].lastIpcObject;
        if (!ipc || !ipc.address)
          continue;
        var title = tops[t].title || ipc.title || "";
        var appClass = ipc["class"] || "";
        var where = ipc.workspace ? ipc.workspace.name : "";
        if (!matchesAll((title + " " + appClass).toLowerCase(), needle))
          continue;
        out.push({
          glyph: "\u{f05af}",
          label: title !== "" ? title : appClass,
          sub: appClass + (where !== "" ? "  ·  workspace " + where : ""),
          kind: "window",
          payload: ipc.address
        });
      }
      return out;
    }

    if (mode === "emoji") {
      for (var e = 0; e < emoji.length && out.length < maxResults; e++) {
        if (!matchesAll(emoji[e].name, needle))
          continue;
        out.push({
          glyph: emoji[e].symbol,
          label: emoji[e].name,
          sub: "",
          kind: "copy",
          payload: emoji[e].symbol
        });
      }
      return out;
    }

    return out;
  }

  function act(item) {
    if (!item)
      return;
    if (item.kind === "prefix") {
      // Not a choice but a start: the mode's prefix goes in the field, and the launcher
      // stays for what comes after it.
      if (root.field)
        root.field.begin(item.payload);
      return;
    }
    hide();
    if (item.kind === "copy")
      Quickshell.execDetached(["wl-copy", "--", item.payload]);
    else if (item.kind === "window")
      Hyprland.dispatch("focuswindow address:" + item.payload);
    else if (item.kind === "run")
      Quickshell.execDetached({
        command: ["uwsm", "app", "--", "bash", "-c", item.payload],
        workingDirectory: Quickshell.env("HOME")
      });
    else if (item.kind === "terminal")
      Quickshell.execDetached({
        command: ["uwsm", "app", "--", "ghostty", "--title=Run", "-e", "bash", "-c", item.payload + "; echo; read -r -n 1 -s -p 'press a key'"],
        workingDirectory: Quickshell.env("HOME")
      });
  }

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

  function showInput(resultPath, promptText, initial) {
    items = [];
    inputMode = true;
    resultFile = resultPath;
    prompt = promptText;
    query = "";
    cursor = 0;
    open = true;

    Qt.callLater(function () {
      if (!root.field)
        return;
      root.field.text = initial;
      root.field.take();
    });
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
    inputMode = false;
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
    else if (root.mode !== "apps")
      act(item);
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
    var command = entry.runInTerminal ? ["uwsm", "app", "--", "ghostty", "-e"].concat(entry.command) : ["uwsm", "app", "--"].concat(entry.command);

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

      // Arrives rather than appears. Only on the way in: closing has to be instant, since
      // what was chosen is already starting and a launcher fading over it is in the way.
      opacity: root.open ? 1 : 0
      scale: root.open ? 1 : 0.97

      Behavior on opacity {
        enabled: root.open
        NumberAnimation {
          duration: Style.motionEnter
          easing.type: Easing.OutCubic
        }
      }
      Behavior on scale {
        enabled: root.open
        NumberAnimation {
          duration: Style.motionEnter
          easing.type: Easing.OutCubic
        }
      }

      Column {
        id: layout

        anchors.fill: parent
        anchors.margins: Style.popupPadding
        spacing: 6

        PanelInput {
          id: input

          width: parent.width
          placeholder: root.selecting ? root.prompt : "Search applications  ·  ? for more"

          Component.onCompleted: root.field = input

          onTextChanged: {
            root.query = text;
            root.cursor = 0;
          }
          onAccepted: {
            if (root.inputMode) {
              // An empty prompt is a cancellation: there is nothing to ask.
              root.open = false;
              root.answer(input.text, input.text !== "");
            } else {
              root.activate(root.results[root.cursor]);
            }
          }
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

              iconSource: (!root.listing && modelData.icon) ? Quickshell.iconPath(modelData.icon, true) : ""
              icon: root.listing ? modelData.glyph : ""
              label: root.listing ? modelData.label : (modelData.name || "")
              sublabel: root.listing ? modelData.sub : (modelData.genericName || modelData.comment || "")
              cursor: root.cursor === index
              onClicked: root.activate(modelData)
            }
          }
        }

        Text {
          width: parent.width
          visible: root.results.length === 0 && !root.inputMode
          // In a mode an empty list is usually a sentence half typed, not a failed search.
          text: root.mode === "calc" ? (root.modeQuery === "" ? "Type a sum" : "Not a sum yet") : root.mode === "run" ? "Type a command" : root.mode === "emoji" && root.emoji.length === 0 ? "Loading…" : "No match"
          color: Color.popupMuted
          font.family: Style.fontFamily
          font.pixelSize: Style.fontSize
          horizontalAlignment: Text.AlignHCenter
        }
      }
    }
  }
}
