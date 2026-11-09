import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Security, under three headings:
//
//   Posture   what state this machine is in: desktop-security's verdicts
//   Events    what has been happening: rules over the journal (desktop-security-events),
//             with a timeline, alerts and a search, in the manner of a SIEM
//   Scanner   the planet: aircraft, ships, malware servers, earthquakes and Wi-Fi, on a
//             globe, from desktop-scanner
//   Advisories  what NCSC-NL has published, and which of it names something on this
//             machine, from desktop-advisories
//
// While the screen is shared the events and the Wi-Fi around you are not drawn. They are a
// list of what was run with sudo and a map of where you are, neither of which is for an
// audience. The planet stays: it is public, and it is why the sharing started.
ColumnLayout {
  id: page

  // desktop-dash security: { posture, events }.
  property var info: null
  // desktop-dash advisories, asked for apart: it goes out to the network.
  property var advisories: null
  property bool active: false
  property real room: 700

  // Said when the search box lets go of the keyboard, so the tab keys work again.
  signal typingDone

  spacing: Style.overviewSpacing

  readonly property var headings: ["posture", "events", "scanner", "advisories"]
  readonly property var titles: ({
      "posture": "Posture",
      "events": "Events",
      "scanner": "Scanner",
      "advisories": "Advisories"
    })
  property int section: 0
  readonly property string heading: headings[section]

  function step(delta) {
    section = (section + delta + headings.length) % headings.length;
  }

  function choose(name) {
    var at = headings.indexOf(name);
    if (at === -1)
      return false;
    section = at;
    return true;
  }

  readonly property var posture: info && info.posture ? info.posture : null
  readonly property var events: info && info.events ? info.events : null
  readonly property var findings: posture && posture.findings ? posture.findings : []
  readonly property var passed: posture && posture.passed ? posture.passed : []

  function levelTone(level) {
    return level === "bad" || level === "high" ? Color.popupUrgent : level === "warn" || level === "medium" ? Color.caution : level === "low" ? Color.popupAccent : Color.popupMuted;
  }

  function ago(seconds) {
    if (seconds === null || seconds === undefined)
      return "never";
    if (seconds < 90)
      return "just now";
    if (seconds < 5400)
      return Math.round(seconds / 60) + "m ago";
    return Math.round(seconds / 3600) + "h ago";
  }

  // --- scanner: its own process, since it can take twenty seconds and must not hold up the
  // one the dashboard asks every other tab through

  property var scan: null
  property var hiddenLayers: ({})
  property var chosenPoint: null
  readonly property bool scanning: page.active && page.heading === "scanner"
  readonly property var layers: scan && scan.layers ? scan.layers : []
  // What the globe draws, replaced only when a feed brought something new. The script is
  // asked every two minutes to keep the ages right, and handing the same ten thousand dots
  // back to the GPU each time would be work for nothing.
  property var drawn: []
  property string drawnStamp: ""

  function askScanner() {
    if (!scanner.running)
      scanner.running = true;
  }

  function toggleLayer(key) {
    var next = {};
    for (var k in hiddenLayers)
      next[k] = hiddenLayers[k];
    next[key] = !next[key];
    hiddenLayers = next;
  }

  Process {
    id: scanner

    command: ["desktop-scanner", "--json"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var answer = JSON.parse(text);
          page.scan = answer;
          var stamp = answer.layers.map(function (layer) {
            return layer.file;
          }).join(" ");
          if (stamp !== page.drawnStamp) {
            page.drawnStamp = stamp;
            page.drawn = answer.layers;
          }
        } catch (error) {
          // An answer that could not be read leaves the last one on screen.
        }
      }
    }
  }
  onScanningChanged: if (scanning)
    askScanner()

  // Each feed has its own age limit in the script; this is only how often it is asked.
  Timer {
    interval: 120000
    repeat: true
    running: page.scanning
    onTriggered: page.askScanner()
  }

  // --- webcams: public ones, around where the globe is looking once it is zoomed in. Asked
  // only when the view has come to rest, and only within Windy's 250 km. Seen from orbit
  // there would be fifty cameras for half a planet, which says nothing.

  property var webcams: null
  property var view: null
  // Above this height the view is a continent, and nobody wants its fifty webcams. It was 45,
  // and nobody zoomed in that far without being told to: a third of the way from the start.
  readonly property real camsFrom: 70
  // From this height they are already asked for, and not shown: on the way in, so that by
  // the time the view is close enough they are there, pictures and all.
  readonly property real preloadFrom: 150
  readonly property bool camsReachable: !hiddenLayers["webcams"] && !!view && view.altitude <= preloadFrom
  // The webcam open in the pop-up, or null.
  property var camOpen: null
  // Where the last answer was asked for: {lat, lon, km, at}.
  property var camAsked: null
  property var liveAsked: null

  // Kilometres between two points, near enough for "has the view moved".
  function apart(a, b) {
    var dlat = (a.lat - b.lat) * 111, dlon = (a.lon - b.lon) * 111 * Math.cos(a.lat * Math.PI / 180);
    return Math.sqrt(dlat * dlat + dlon * dlon);
  }

  // Asking again is a process, a request, and fifty pictures. Not for a view that moved a
  // little, within a radius already asked about and while the pictures' links still work.
  function stillCovered(asked, km, within, seconds) {
    return !!asked && Date.now() - asked.at < seconds * 1000 && apart(asked, view) + km <= asked.km * within;
  }

  function playTimelapse(cam) {
    if (cam && cam.player)
      Quickshell.execDetached(["desktop-launch-webapp", cam.player]);
  }
  readonly property bool camsWanted: !hiddenLayers["webcams"] && !!view && view.altitude <= camsFrom
  readonly property var cams: webcams && webcams.cams && camsWanted ? webcams.cams : []
  readonly property var camLayer: webcams && webcams.layer && webcams.layer.file !== "" && camsWanted ? [webcams.layer] : []

  // --- aircraft, live: the same window as the webcams, from adsb.lol, every ten seconds.
  // While they are there, OpenSky's five-minute-old aircraft are not drawn: every plane in
  // view would otherwise be there twice, once where it is and once where it was.
  property var liveAnswer: null
  readonly property bool liveWanted: !hiddenLayers["live"] && !!view && view.altitude <= camsFrom
  readonly property var liveLayer: liveWanted && liveAnswer && liveAnswer.layer && liveAnswer.layer.file !== "" ? [liveAnswer.layer] : []
  readonly property var shownHidden: {
    var out = {};
    for (var k in hiddenLayers)
      out[k] = hiddenLayers[k];
    if (liveLayer.length > 0)
      out["planes"] = true;
    return out;
  }

  function askLive(timed) {
    if (!liveWanted || liveProc.running)
      return;
    var km = Math.round(Math.max(15, Math.min(460, view.altitude * Math.tan(22.5 * Math.PI / 180) * 63.7 * 1.6)));
    // The timer asks every ten seconds anyway; a view that settled close by waits for it.
    if (!timed && stillCovered(liveAsked, km * 0.1, 1.15, 10))
      return;
    liveAsked = {
      lat: view.lat,
      lon: view.lon,
      km: km,
      at: Date.now()
    };
    liveProc.command = ["desktop-scanner", "--live", view.lat.toFixed(4), view.lon.toFixed(4), String(km)];
    liveProc.running = true;
  }

  Process {
    id: liveProc

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          page.liveAnswer = JSON.parse(text);
        } catch (error) {
          // The last ones stay.
        }
      }
    }
  }

  Timer {
    interval: 10000
    repeat: true
    running: page.scanning && page.liveWanted
    onTriggered: page.askLive(true)
  }

  readonly property var liveRow: ({
      key: "live",
      label: "Aircraft, live (adsb.lol)",
      colour: "#7dcfff",
      count: liveLayer.length > 0 ? liveAnswer.layer.count : 0,
      age: null,
      ok: !liveAnswer || liveAnswer.ok,
      note: !view || view.altitude > camsFrom ? "Zoom in to a region for live positions" : liveAnswer ? (liveAnswer.note || "within " + liveAnswer.km + " km, every 10 s  ·  data adsb.lol, ODbL") : ""
    })

  function askWebcams() {
    if (!camsReachable || webcamProc.running)
      return;
    // Half the height of the view, in kilometres, and a little more: a degree is 111 km and
    // the planet's radius is 100 here.
    var km = Math.round(Math.max(15, Math.min(250, view.altitude * Math.tan(22.5 * Math.PI / 180) * 63.7 * 1.3)));
    if (stillCovered(camAsked, Math.min(km, 60), 1, 420))
      return;
    camAsked = {
      lat: view.lat,
      lon: view.lon,
      km: km,
      at: Date.now()
    };
    webcamProc.command = ["desktop-scanner", "--webcams", view.lat.toFixed(4), view.lon.toFixed(4), String(km)];
    webcamProc.running = true;
  }

  Process {
    id: webcamProc

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          page.webcams = JSON.parse(text);
        } catch (error) {
          // The last ones stay.
        }
      }
    }
  }

  // Windy's image links expire; a view left alone is asked again before they do.
  Timer {
    interval: 420000
    repeat: true
    running: page.scanning && page.camsReachable
    onTriggered: {
      page.camAsked = null;
      page.askWebcams();
    }
  }

  // The thumbnails, fetched as soon as the answer is in, even before the card shows them:
  // into the image cache, which the card then draws from.
  Item {
    visible: false

    Repeater {
      model: page.webcams && page.webcams.cams ? page.webcams.cams : []

      delegate: Image {
        required property var modelData

        source: modelData.thumb
        asynchronous: true
        cache: true
      }
    }
  }

  readonly property var camRow: ({
      key: "webcams",
      label: "Webcams (Windy)",
      colour: "#e0af68",
      count: cams.length,
      age: null,
      ok: !webcams || webcams.connected !== false,
      note: webcams && webcams.connected === false ? "Not connected: needs a free Windy key" : !view || view.altitude > camsFrom ? "Zoom in to a region to look" : webcams && webcams.layer ? (webcams.layer.note || "within " + webcams.km + " km of the middle of the view") : ""
    })

  // One aircraft, asked for when it is clicked.
  property var plane: null

  onChosenPointChanged: {
    plane = null;
    if (chosenPoint && (chosenPoint.key === "planes" || chosenPoint.key === "live") && chosenPoint.hex) {
      aircraft.command = ["desktop-scanner", "--aircraft", chosenPoint.hex, chosenPoint.name];
      aircraft.running = false;
      aircraft.running = true;
    }
  }

  Process {
    id: aircraft

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          page.plane = JSON.parse(text);
        } catch (error) {
          page.plane = null;
        }
      }
    }
  }

  // --- the search over the events, Elastic-fashion: words, severity:high, rule:sudo-run,
  // source:kernel, and a minus for "not"

  property string query: ""

  function matches(event, terms) {
    for (var i = 0; i < terms.length; i++) {
      var term = terms[i], not = term.charAt(0) === "-";
      if (not)
        term = term.slice(1);
      var colon = term.indexOf(":"), found;
      if (colon > 0) {
        var field = term.slice(0, colon), wanted = term.slice(colon + 1);
        found = String(event[field] || "").toLowerCase().indexOf(wanted) !== -1;
      } else {
        found = (event.message + " " + event.rule + " " + event.source).toLowerCase().indexOf(term) !== -1;
      }
      if (found === not)
        return false;
    }
    return true;
  }

  readonly property var shownEvents: {
    var all = events && events.events ? events.events : [];
    var terms = query.toLowerCase().split(/\s+/).filter(function (t) {
      return t !== "" && t !== "-";
    });
    return terms.length === 0 ? all : all.filter(function (e) {
      return page.matches(e, terms);
    });
  }

  // --- advisories

  property string advisoryFilter: "all"
  // The one opened, by its id, so a refresh does not close it.
  property string openAdvisory: ""
  readonly property var allAdvisories: advisories && advisories.items ? advisories.items : []
  readonly property var shownAdvisories: allAdvisories.filter(function (item) {
    if (advisoryFilter === "mine")
      return item.mine.length > 0;
    if (advisoryFilter === "high")
      return item.likelihood === "H" && item.damage === "H";
    return true;
  })

  function ratingTone(item) {
    if (item.likelihood === "H" && item.damage === "H")
      return Color.popupUrgent;
    return item.damage === "H" ? Color.caution : Color.popupMuted;
  }

  // --- headings

  Row {
    spacing: Style.sectionSpacing

    Choice {
      options: page.headings.map(function (name) {
        return {
          id: name,
          label: page.titles[name]
        };
      })
      chosen: page.heading
      textSize: Style.fontSize + 1
      onPicked: id => page.choose(id)
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      leftPadding: Style.sectionSpacing
      text: "↑ ↓ to change"
      color: Color.popupBorder
      font.family: Style.fontFamily
      font.pixelSize: Style.fontSize - 2
    }
  }

  // --- posture

  GridLayout {
    id: postureGrid

    Layout.fillWidth: true
    visible: page.heading === "posture"
    columns: 2
    columnSpacing: Style.overviewSpacing
    rowSpacing: Style.overviewSpacing

    Card {
      order: 0
      appear: page.active
      Layout.preferredWidth: 1
      Layout.columnSpan: 2
      icon: "\u{f0483}"
      title: "What needs looking at"
      figure: String(page.findings.length)
      tone: page.findings.some(function (f) {
        return f.level === "bad";
      }) ? Color.popupUrgent : page.findings.some(function (f) {
        return f.level === "warn";
      }) ? Color.caution : Color.good

      Repeater {
        model: page.findings

        delegate: Column {
          required property var modelData

          width: parent.width
          spacing: 2
          bottomPadding: Style.sectionSpacing

          Row {
            spacing: 8

            Rectangle {
              anchors.verticalCenter: parent.verticalCenter
              width: 8
              height: 8
              radius: 4
              color: page.levelTone(modelData.level)
            }
            Text {
              text: modelData.title
              textFormat: Text.PlainText
              color: Color.popupText
              font.family: Style.fontFamily
              font.pixelSize: Style.fontSize + 1
              font.weight: Style.barLabelWeight
            }
          }
          Quiet {
            text: modelData.detail
          }
          Quiet {
            visible: !!modelData.fix
            text: "→ " + modelData.fix
            color: Color.popupAccent
          }
        }
      }
      Quiet {
        visible: !!page.posture && page.findings.length === 0
        text: "Nothing: every check passed."
      }
    }

    Card {
      order: 1
      appear: page.active
      Layout.fillWidth: true
      icon: "\u{f0f79}"
      title: "This machine"
      tone: Color.popupAccent

      Repeater {
        model: {
          var f = page.posture && page.posture.facts ? page.posture.facts : null;
          if (!f)
            return [];
          return [
            { label: "SELinux", value: f.selinux, good: f.selinux === "Enforcing" },
            { label: "Firewall zone", value: (f.firewall || []).join(", ") || "none", good: (f.firewall || []).length > 0 },
            { label: "Disk encryption", value: f.encrypted ? "On" : "Off", good: f.encrypted },
            { label: "Secure Boot", value: f.secureBoot ? "On" : "Off", good: f.secureBoot },
            { label: "Firmware (HSI)", value: f.hsi !== undefined ? f.hsi + " of 5" : "unknown", good: f.hsi >= 2 },
            { label: "Open to the network", value: (f.exposed || []).join(", ") || "Nothing", good: (f.exposed || []).length === 0 },
            { label: "Security updates waiting", value: String(f.securityUpdates), good: f.securityUpdates === 0 },
            { label: "Failed logins", value: String(f.failedLogins), good: f.failedLogins === 0 },
            { label: "ClamAV signatures", value: f.clamavSignatureDays !== undefined ? f.clamavSignatureDays + " days old" : "none", good: f.clamavSignatureDays !== undefined && f.clamavSignatureDays < 8 }
          ];
        }

        delegate: Item {
          required property var modelData

          width: parent.width
          height: Style.rowHeight - 6

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: modelData.label
            color: Color.popupMuted
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSize
          }
          Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: modelData.value
            textFormat: Text.PlainText
            color: modelData.good ? Color.good : Color.caution
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSize
          }
        }
      }
    }

    Card {
      order: 2
      appear: page.active
      Layout.fillWidth: true
      icon: "\u{f012c}"
      title: "Passed"
      figure: String(page.passed.length)
      tone: Color.good

      Repeater {
        model: page.passed

        delegate: Item {
          required property var modelData

          width: parent.width
          height: Style.rowHeight - 6

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "\u{f012c}  " + modelData.title
            textFormat: Text.PlainText
            color: Color.popupMuted
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSize
          }
        }
      }
    }
  }

  // --- events

  Quiet {
    Layout.fillWidth: true
    visible: page.heading === "events" && Sharing.active
    text: "Not shown while the screen is shared: it lists what was run and by whom."
  }

  ColumnLayout {
    Layout.fillWidth: true
    visible: page.heading === "events" && !Sharing.active
    spacing: Style.overviewSpacing

    // An alert goes first and in colour: it is why anyone would open this page at all.
    Repeater {
      model: page.events && page.events.alerts ? page.events.alerts : []

      delegate: Rectangle {
        required property var modelData

        Layout.fillWidth: true
        implicitHeight: alertLine.implicitHeight + Style.popupPadding * 2
        radius: Style.radius
        color: Qt.rgba(tone.r, tone.g, tone.b, 0.12)
        border.width: 1
        border.color: tone

        readonly property color tone: page.levelTone(modelData.severity)

        Text {
          id: alertLine

          anchors.fill: parent
          anchors.margins: Style.popupPadding
          text: "\u{f0026}  " + modelData.title + "  ·  " + modelData.count + " times, " + Qt.formatDateTime(new Date(modelData.from * 1000), "ddd HH:mm") + " to " + Qt.formatDateTime(new Date(modelData.to * 1000), "HH:mm")
          textFormat: Text.PlainText
          color: parent.tone
          font.family: Style.fontFamily
          font.pixelSize: Style.fontSize + 1
          wrapMode: Text.WordWrap
        }
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.overviewSpacing

      Card {
        order: 0
        appear: page.active
        Layout.preferredWidth: 340
        Layout.fillWidth: false
        icon: "\u{f0483}"
        title: "Last " + (page.events ? page.events.hours : 24) + " hours"
        figure: page.events ? String(page.events.total) : ""
        tone: Color.popupAccent

        Grid {
          columns: 2
          columnSpacing: Style.overviewSpacing
          rowSpacing: Style.sectionSpacing
          topPadding: 6

          Repeater {
            model: ["high", "medium", "low", "info"]

            delegate: Figure {
              required property string modelData

              appear: page.active
              value: page.events && page.events.severity ? page.events.severity[modelData] : 0
              label: modelData
              tone: page.levelTone(modelData)
            }
          }
        }
      }

      Card {
        order: 1
        appear: page.active
        Layout.fillWidth: true
        icon: "\u{f012d}"
        title: "Timeline"
        tone: Color.popupAccent

        Bars {
          width: parent.width
          height: 148
          appear: page.active
          sparse: true
          values: {
            var rows = page.events && page.events.timeline ? page.events.timeline : [];
            return rows.map(function (row, i) {
              return {
                label: i % 4 === 0 ? row.label : "",
                value: row.value
              };
            });
          }
        }
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.overviewSpacing

      Card {
        order: 2
        appear: page.active
        Layout.preferredWidth: 440
        Layout.fillWidth: false
        Layout.alignment: Qt.AlignTop
        fixedHeight: Math.max(320, page.room - 400)
        icon: "\u{f0493}"
        title: "Rules"
        figure: page.events ? String(page.events.rules.length) : ""
        tone: Color.popupAccent

        // What was looked for as well as what was found: a rule at zero says nobody tried.
        Repeater {
          model: page.events ? page.events.rules.slice().sort(function (a, b) {
            return b.count - a.count;
          }) : []

          delegate: Item {
            required property var modelData

            width: parent.width
            height: Style.rowHeight - 4
            opacity: modelData.count > 0 ? 1 : 0.5

            Rectangle {
              anchors.fill: parent
              radius: Style.radius
              color: ruleOver.containsMouse ? Color.popupHover : "transparent"
            }
            Rectangle {
              id: ruleDot

              anchors.verticalCenter: parent.verticalCenter
              x: 6
              width: 8
              height: 8
              radius: 4
              color: page.levelTone(modelData.severity)
            }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              anchors.left: ruleDot.right
              anchors.leftMargin: 8
              anchors.right: ruleCount.left
              anchors.rightMargin: 8
              text: modelData.title
              textFormat: Text.PlainText
              elide: Text.ElideRight
              color: Color.popupText
              font.family: Style.fontFamily
              font.pixelSize: Style.fontSize - 1
            }
            Text {
              id: ruleCount

              anchors.verticalCenter: parent.verticalCenter
              anchors.right: parent.right
              anchors.rightMargin: 6
              text: (modelData.technique ? modelData.technique + "   " : "") + modelData.count
              color: Color.popupMuted
              font.family: Style.fontFamily
              font.pixelSize: Style.fontSize - 2
            }
            MouseArea {
              id: ruleOver

              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                var wanted = "rule:" + modelData.id;
                search.text = page.query === wanted ? "" : wanted;
              }
            }
          }
        }
      }

      Card {
        order: 3
        appear: page.active
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop
        fixedHeight: Math.max(320, page.room - 400)
        icon: "\u{f0349}"
        title: "Events"
        figure: String(page.shownEvents.length)
        tone: Color.popupAccent

        PanelInput {
          id: search

          width: parent.width
          placeholder: "Search:  sudo   severity:high   rule:usb-new   source:kernel   -usb"
          onTextChanged: page.query = text
          onAccepted: {
            release();
            page.typingDone();
          }
          onCancelled: {
            text = "";
            release();
            page.typingDone();
          }
        }
        Item {
          width: 1
          height: 6
        }
        Repeater {
          model: page.shownEvents

          delegate: Item {
            required property var modelData

            width: parent.width
            height: line.implicitHeight + 8

            Rectangle {
              id: eventDot

              y: 8
              x: 4
              width: 7
              height: 7
              radius: 4
              color: page.levelTone(modelData.severity)
            }
            Text {
              id: eventTime

              x: 18
              y: 3
              width: 92
              text: Qt.formatDateTime(new Date(modelData.at * 1000), "ddd HH:mm:ss")
              color: Color.popupMuted
              font.family: Style.fontFamily
              font.pixelSize: Style.fontSize - 2
            }
            Text {
              id: line

              x: 112
              y: 3
              width: parent.width - x - 4
              text: modelData.source + "  " + modelData.message
              textFormat: Text.PlainText
              wrapMode: Text.Wrap
              maximumLineCount: 2
              elide: Text.ElideRight
              color: Color.popupText
              font.family: Style.fontFamily
              font.pixelSize: Style.fontSize - 2
            }
          }
        }
        Quiet {
          visible: page.events !== null && page.shownEvents.length === 0
          text: page.query !== "" ? "Nothing matches that." : "Nothing recognised in this period."
        }
      }
    }
  }

  // --- advisories

  ColumnLayout {
    Layout.fillWidth: true
    visible: page.heading === "advisories"
    spacing: Style.overviewSpacing

    Unconnected {
      visible: !!page.advisories && !page.advisories.connected
      how: page.advisories && page.advisories.how ? page.advisories.how : []
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.overviewSpacing

      Card {
        order: 0
        appear: page.active
        Layout.preferredWidth: 340
        Layout.fillWidth: false
        Layout.alignment: Qt.AlignTop
        fixedHeight: Math.max(320, page.room - 70)
        icon: "\u{f0483}"
        title: "NCSC-NL"
        tone: Color.popupAccent

        Grid {
          columns: 2
          columnSpacing: Style.overviewSpacing
          rowSpacing: Style.sectionSpacing
          topPadding: 6

          Figure {
            appear: page.active
            value: page.advisories ? page.advisories.highHigh || 0 : 0
            label: "high / high"
            tone: value > 0 ? Color.popupUrgent : Color.good
          }
          Figure {
            appear: page.active
            value: page.advisories ? page.advisories.mine || 0 : 0
            label: "name yours"
            tone: value > 0 ? Color.caution : Color.good
          }
        }
        Item {
          width: 1
          height: Style.sectionSpacing
        }
        Choice {
          options: [
            { id: "all", label: "All" },
            { id: "mine", label: "Yours" },
            { id: "high", label: "High" }
          ]
          chosen: page.advisoryFilter
          onPicked: id => page.advisoryFilter = id
        }
        Item {
          width: 1
          height: Style.sectionSpacing
        }
        Quiet {
          text: "The rating is likelihood / damage, the NCSC's own, and is shown as they wrote it."
        }
        Item {
          width: 1
          height: 6
        }
        Quiet {
          text: "\"Yours\" means an advisory names something installed here or on your own list. It does not say your version is affected: the advisory does."
        }
        Item {
          width: 1
          height: 6
        }
        Quiet {
          visible: !!page.advisories && page.advisories.fresh === false
          color: Color.caution
          text: "The NCSC could not be reached: this is the last copy."
        }
        Quiet {
          visible: !!page.advisories && page.advisories.age !== null && page.advisories.age !== undefined
          text: page.advisories ? "Asked " + page.ago(page.advisories.age) + "  ·  at most every half hour" : ""
        }
      }

      Card {
        order: 1
        appear: page.active
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop
        fixedHeight: Math.max(320, page.room - 70)
        icon: "\u{f0349}"
        title: "Advisories"
        figure: String(page.shownAdvisories.length)
        tone: Color.popupAccent

        Repeater {
          model: page.shownAdvisories

          delegate: Item {
            required property var modelData

            readonly property bool opened: page.openAdvisory === modelData.id

            width: parent.width
            height: entry.implicitHeight + 10

            Rectangle {
              anchors.fill: parent
              radius: Style.radius
              color: opened || advisoryOver.containsMouse ? Color.popupHover : "transparent"
            }
            // Under the text, so the link in an opened entry still takes its own click.
            MouseArea {
              id: advisoryOver

              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: page.openAdvisory = opened ? "" : modelData.id
            }

            Column {
              id: entry

              x: 6
              y: 5
              width: parent.width - 12
              spacing: 3

              Item {
                width: parent.width
                height: advisoryTitle.implicitHeight

                Rectangle {
                  id: rating

                  anchors.verticalCenter: parent.verticalCenter
                  width: ratingText.implicitWidth + 12
                  height: ratingText.implicitHeight + 2
                  radius: Style.radius
                  color: Qt.rgba(tone.r, tone.g, tone.b, 0.15)
                  border.width: 1
                  border.color: tone

                  readonly property color tone: page.ratingTone(modelData)

                  Text {
                    id: ratingText

                    anchors.centerIn: parent
                    text: modelData.likelihood + "/" + modelData.damage
                    color: parent.tone
                    font.family: Style.fontFamily
                    font.pixelSize: Style.fontSize - 2
                    font.weight: Style.barLabelWeight
                  }
                }
                Text {
                  id: advisoryTitle

                  anchors.left: rating.right
                  anchors.leftMargin: 8
                  anchors.right: advisoryDate.left
                  anchors.rightMargin: 8
                  text: modelData.title
                  textFormat: Text.PlainText
                  elide: Text.ElideRight
                  color: Color.popupText
                  font.family: Style.fontFamily
                  font.pixelSize: Style.fontSize
                }
                Text {
                  id: advisoryDate

                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  text: Qt.formatDateTime(new Date(modelData.at * 1000), "d MMM")
                  color: Color.popupMuted
                  font.family: Style.fontFamily
                  font.pixelSize: Style.fontSize - 2
                }
              }
              Text {
                width: parent.width
                text: {
                  var parts = [modelData.id + (modelData.updated ? "  ·  updated, v" + modelData.version : "")];
                  if (modelData.mine.length > 0)
                    parts.push("yours: " + modelData.mine.join(", "));
                  return parts.join("  ·  ");
                }
                textFormat: Text.PlainText
                color: modelData.mine.length > 0 ? Color.caution : Color.popupMuted
                font.family: Style.fontFamily
                font.pixelSize: Style.fontSize - 2
              }
              Text {
                visible: opened
                width: parent.width
                topPadding: 4
                text: modelData.summary
                textFormat: Text.PlainText
                wrapMode: Text.WordWrap
                color: Color.popupText
                font.family: Style.fontFamily
                font.pixelSize: Style.fontSize - 1
              }
              Text {
                visible: opened && modelData.link !== ""
                topPadding: 4
                text: "\u{f0337}  Read it at the NCSC"
                color: readOver.containsMouse ? Color.popupText : Color.popupAccent
                font.family: Style.fontFamily
                font.pixelSize: Style.fontSize - 1

                MouseArea {
                  id: readOver

                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: Qt.openUrlExternally(modelData.link)
                }
              }
            }
          }
        }
        Quiet {
          visible: page.advisories !== null && page.shownAdvisories.length === 0
          text: page.advisoryFilter === "mine" ? "None of them names anything on this machine." : page.advisoryFilter === "high" ? "None rated high likelihood and high damage." : "Nothing published."
        }
      }
    }
  }

  // --- scanner

  RowLayout {
    Layout.fillWidth: true
    Layout.preferredHeight: Math.max(520, page.room - 60)
    visible: page.heading === "scanner"
    spacing: Style.overviewSpacing

    Rectangle {
      Layout.fillWidth: true
      Layout.fillHeight: true
      radius: Style.radius
      color: "#05070d"
      border.width: 1
      border.color: Color.popupBorder
      clip: true

      // Loaded for as long as this heading is on show. It keeps the GPU's memory and every
      // frame for when they are wanted, and it means a machine without QtQuick3D loses the
      // globe and says why, rather than losing the whole shell to an import that failed.
      Loader {
        id: globeLoader

        anchors.fill: parent
        anchors.margins: 1
        active: page.scanning
        source: "Globe.qml"
      }
      Binding {
        target: globeLoader.item
        when: globeLoader.status === Loader.Ready
        property: "running"
        value: page.scanning
      }
      Binding {
        target: globeLoader.item
        when: globeLoader.status === Loader.Ready
        property: "layers"
        value: page.drawn
      }
      Binding {
        target: globeLoader.item
        when: globeLoader.status === Loader.Ready
        property: "hidden"
        value: page.shownHidden
      }
      // Where you live is not for a shared screen.
      Binding {
        target: globeLoader.item
        when: globeLoader.status === Loader.Ready
        property: "home"
        value: page.scan && !Sharing.active ? page.scan.home : null
      }
      Binding {
        target: globeLoader.item
        when: globeLoader.status === Loader.Ready
        property: "extra"
        value: page.liveLayer.concat(page.camLayer)
      }
      Connections {
        target: globeLoader.item
        ignoreUnknownSignals: true

        function onChosen(point) {
          page.chosenPoint = point;
          page.camOpen = point && point.key === "webcams" ? page.cams[point.cam] || null : null;
        }
        function onLooked(lat, lon, altitude) {
          page.view = {
            lat: lat,
            lon: lon,
            altitude: altitude
          };
          page.askWebcams();
          page.askLive(false);
        }
      }

      // A webcam, opened over the globe: its picture at the size Windy serves it, which their
      // terms ask not to be enlarged, and its timelapse a click away. A click beside it closes.
      Rectangle {
        anchors.fill: parent
        z: 10
        visible: page.camOpen !== null
        color: Qt.rgba(0, 0, 0, 0.55)

        MouseArea {
          anchors.fill: parent
          onClicked: page.camOpen = null
        }

        Rectangle {
          anchors.centerIn: parent
          width: 440
          height: camColumn.implicitHeight + 32
          radius: Style.radius
          color: Color.popupBackground
          border.width: 1
          border.color: "#e0af68"

          // Clicks inside stay inside.
          MouseArea {
            anchors.fill: parent
          }

          Column {
            id: camColumn

            readonly property var cam: page.camOpen

            x: 16
            y: 16
            width: parent.width - 32
            spacing: 8

            Item {
              width: parent.width
              height: camTitle.implicitHeight

              Text {
                id: camTitle

                width: parent.width - 30
                text: camColumn.cam ? camColumn.cam.title : ""
                textFormat: Text.PlainText
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
                color: Color.popupText
                font.family: Style.fontFamily
                font.pixelSize: Style.fontSize + 1
                font.weight: Style.barLabelWeight
              }
              Text {
                anchors.right: parent.right
                text: "\u{f0156}"
                color: closeOver.containsMouse ? Color.popupText : Color.popupMuted
                font.family: Style.fontFamily
                font.pixelSize: Style.fontSize + 2

                MouseArea {
                  id: closeOver

                  anchors.fill: parent
                  anchors.margins: -6
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: page.camOpen = null
                }
              }
            }
            Quiet {
              text: {
                var c = camColumn.cam;
                if (!c)
                  return "";
                var when = c.updated ? Date.parse(c.updated) : NaN;
                return c.place + (isNaN(when) ? "" : "  ·  picture from " + page.ago(Math.max(0, (Date.now() - when) / 1000)));
              }
            }
            Image {
              anchors.horizontalCenter: parent.horizontalCenter
              width: Math.min(parent.width, 400)
              height: width * 224 / 400
              source: camColumn.cam ? camColumn.cam.image : ""
              fillMode: Image.PreserveAspectFit
              asynchronous: true
              cache: true

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: page.playTimelapse(camColumn.cam)
              }
              Text {
                anchors.centerIn: parent
                visible: parent.status === Image.Loading
                text: "…"
                color: Color.popupMuted
              }
            }
            Row {
              spacing: Style.overviewSpacing

              Text {
                visible: !!camColumn.cam && camColumn.cam.player !== ""
                text: "\u{f040a}  Today's timelapse"
                color: playOver.containsMouse ? Color.popupText : Color.popupAccent
                font.family: Style.fontFamily
                font.pixelSize: Style.fontSize

                MouseArea {
                  id: playOver

                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: page.playTimelapse(camColumn.cam)
                }
              }
              Text {
                visible: !!camColumn.cam && camColumn.cam.link !== ""
                text: "\u{f0337}  At Windy"
                color: pageOver.containsMouse ? Color.popupText : Color.popupMuted
                font.family: Style.fontFamily
                font.pixelSize: Style.fontSize

                MouseArea {
                  id: pageOver

                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: Qt.openUrlExternally(camColumn.cam.link)
                }
              }
            }
            Text {
              text: "Webcams provided by <a href=\"https://www.windy.com/\">Windy.com</a> — <a href=\"https://www.windy.com/webcams/add\">add a webcam</a>"
              textFormat: Text.StyledText
              linkColor: Color.popupAccent
              color: Color.popupMuted
              font.family: Style.fontFamily
              font.pixelSize: Style.fontSize - 2
              onLinkActivated: link => Qt.openUrlExternally(link)
            }
          }
        }
      }

      // What zooming in will bring, said where the eye is: in the layer list it was missed.
      Rectangle {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 12
        visible: globeLoader.status === Loader.Ready && page.layers.length > 0 && (!page.view || page.view.altitude > page.camsFrom)
        width: zoomHint.implicitWidth + 24
        height: zoomHint.implicitHeight + 10
        radius: Style.radius
        color: Qt.rgba(0, 0, 0, 0.55)

        Text {
          id: zoomHint

          anchors.centerIn: parent
          text: "Scroll in on a region for live aircraft and webcams"
          color: Color.popupText
          font.family: Style.fontFamily
          font.pixelSize: Style.fontSize - 1
        }
      }

      Quiet {
        anchors.centerIn: parent
        width: implicitWidth
        visible: page.layers.length === 0 || globeLoader.status === Loader.Error
        text: globeLoader.status === Loader.Error ? "The globe needs qt6-qtquick3d and qt6-qtshadertools." : scanner.running ? "Asking the feeds…" : ""
      }
    }

    ColumnLayout {
      Layout.preferredWidth: 340
      Layout.maximumWidth: 340
      Layout.fillHeight: true
      spacing: Style.sectionSpacing * 2

      Card {
        order: 0
        appear: page.active
        icon: "\u{f0349}"
        title: "Layers"
        tone: Color.popupAccent

        Repeater {
          model: page.layers.length > 0 ? page.layers.concat([page.liveRow, page.camRow]) : []

          delegate: Item {
            required property var modelData

            readonly property bool off: !!page.hiddenLayers[modelData.key]

            width: parent.width
            height: layerRow.implicitHeight + 8
            opacity: off || modelData.count === 0 ? 0.5 : 1

            Rectangle {
              anchors.fill: parent
              radius: Style.radius
              color: layerOver.containsMouse ? Color.popupHover : "transparent"
            }
            Column {
              id: layerRow

              x: 6
              y: 4
              width: parent.width - 12
              spacing: 1

              Item {
                width: parent.width
                height: layerName.implicitHeight

                Rectangle {
                  anchors.verticalCenter: parent.verticalCenter
                  width: 10
                  height: 10
                  radius: 5
                  color: off ? "transparent" : modelData.colour
                  border.width: 1
                  border.color: modelData.colour
                }
                Text {
                  id: layerName

                  x: 18
                  text: modelData.label
                  color: Color.popupText
                  font.family: Style.fontFamily
                  font.pixelSize: Style.fontSize
                }
                Text {
                  anchors.right: parent.right
                  text: modelData.count.toLocaleString(Qt.locale("en_GB"), "f", 0)
                  color: Color.popupText
                  font.family: Style.fontFamily
                  font.pixelSize: Style.fontSize
                  font.weight: Style.barLabelWeight
                }
              }
              Text {
                x: 18
                width: parent.width - 18
                visible: text !== ""
                text: [modelData.age !== null ? page.ago(modelData.age) : "", modelData.note].filter(function (part) {
                  return part !== "";
                }).join("  ·  ")
                textFormat: Text.PlainText
                wrapMode: Text.WordWrap
                color: modelData.ok ? Color.popupMuted : Color.caution
                font.family: Style.fontFamily
                font.pixelSize: Style.fontSize - 2
              }
            }
            MouseArea {
              id: layerOver

              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: page.toggleLayer(modelData.key)
            }
          }
        }
      }

      Card {
        order: 1
        appear: page.active
        visible: page.chosenPoint !== null
        icon: "\u{f0349}"
        title: page.chosenPoint ? page.chosenPoint.layer : ""
        tone: page.chosenPoint ? page.chosenPoint.colour : Color.popupAccent

        Text {
          text: page.chosenPoint ? page.chosenPoint.name : ""
          textFormat: Text.PlainText
          color: Color.popupText
          font.family: Style.fontFamily
          font.pixelSize: Style.fontSize + 3
          font.weight: Style.barLabelWeight
        }
        Quiet {
          text: page.chosenPoint ? page.chosenPoint.detail : ""
          visible: text !== ""
        }
        // What hexdb.io knows about the airframe, if it is a plane and it knows anything.
        Repeater {
          model: {
            var p = page.plane;
            if (!p)
              return [];
            return [
              { label: "Type", value: [p.maker, p.type].filter(function (v) { return v; }).join(" ") },
              { label: "Registration", value: p.registration },
              { label: "Owner", value: p.owner },
              { label: "Usually flies", value: p.route }
            ].filter(function (row) {
              return row.value;
            });
          }

          delegate: Column {
            required property var modelData

            width: parent.width
            topPadding: 6

            Text {
              text: modelData.label
              color: Color.popupMuted
              font.family: Style.fontFamily
              font.pixelSize: Style.fontSize - 2
            }
            Text {
              width: parent.width
              text: modelData.value
              textFormat: Text.PlainText
              wrapMode: Text.WordWrap
              color: Color.popupText
              font.family: Style.fontFamily
              font.pixelSize: Style.fontSize
            }
          }
        }
        Quiet {
          topPadding: 6
          text: {
            var c = page.chosenPoint;
            if (!c)
              return "";
            var at = c.lat.toFixed(3) + ", " + c.lon.toFixed(3);
            return c.heading !== null && c.heading !== undefined ? at + "  ·  heading " + Math.round(c.heading) + "°" : at;
          }
        }
        // A webcam: its picture, which goes to its page at Windy, as their terms ask of every
        // picture shown.
        Image {
          readonly property var cam: page.chosenPoint && page.chosenPoint.key === "webcams" ? page.cams[page.chosenPoint.cam] || null : null

          visible: !!cam && cam.image !== ""
          width: parent.width
          height: visible ? width * 9 / 16 : 0
          source: cam ? cam.image : ""
          fillMode: Image.PreserveAspectFit
          asynchronous: true
          cache: false

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: page.camOpen = parent.cam
          }
        }
        Text {
          visible: !!page.chosenPoint && !!page.chosenPoint.link
          topPadding: 6
          text: "\u{f0337}  Read about it"
          color: eventOver.containsMouse ? Color.popupText : Color.popupAccent
          font.family: Style.fontFamily
          font.pixelSize: Style.fontSize

          MouseArea {
            id: eventOver

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Qt.openUrlExternally(page.chosenPoint.link)
          }
        }
        Text {
          visible: !!page.plane && page.plane.track !== ""
          topPadding: 6
          text: "\u{f0337}  Track it live"
          color: trackOver.containsMouse ? Color.popupText : Color.popupAccent
          font.family: Style.fontFamily
          font.pixelSize: Style.fontSize

          MouseArea {
            id: trackOver

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Qt.openUrlExternally(page.plane.track)
          }
        }
      }

      Card {
        order: 2
        appear: page.active
        visible: page.camsWanted && !!page.webcams
        icon: "\u{f0567}"
        title: "Webcams here"
        figure: page.cams.length > 0 ? String(page.cams.length) : ""
        tone: "#e0af68"
        fixedHeight: page.cams.length > 0 ? 300 : 0

        Repeater {
          model: page.webcams && page.webcams.connected === false ? page.webcams.how : []

          delegate: Quiet {
            required property var modelData

            text: modelData
          }
        }
        Flow {
          width: parent.width
          spacing: 6

          Repeater {
            model: page.cams

            delegate: Image {
              required property var modelData
              required property int index

              width: (parent.width - 6) / 2
              height: width * 9 / 16
              source: modelData.thumb
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
              cache: true

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  var point = {
                    lat: modelData.lat,
                    lon: modelData.lon,
                    name: modelData.title,
                    detail: modelData.place,
                    layer: "Webcam",
                    key: "webcams",
                    colour: "#e0af68",
                    cam: index,
                    hex: "",
                    heading: null
                  };
                  page.chosenPoint = point;
                  page.camOpen = modelData;
                  if (globeLoader.item)
                    globeLoader.item.picked = point;
                }
              }
            }
          }
        }
        // Their terms: a line in the corner, linking to them and to adding a webcam.
        Text {
          visible: page.cams.length > 0
          topPadding: 6
          text: "Webcams provided by <a href=\"https://www.windy.com/\">Windy.com</a> — <a href=\"https://www.windy.com/webcams/add\">add a webcam</a>"
          textFormat: Text.StyledText
          linkColor: Color.popupAccent
          color: Color.popupMuted
          font.family: Style.fontFamily
          font.pixelSize: Style.fontSize - 2
          onLinkActivated: link => Qt.openUrlExternally(link)
        }
      }

      Card {
        order: 3
        appear: page.active
        Layout.fillHeight: true
        fixedHeight: 1
        icon: "\u{f05a9}"
        title: "Wi-Fi heard here"
        figure: page.scan && !Sharing.active ? String(page.scan.near.length) : ""
        tone: Color.popupAccent

        Quiet {
          visible: Sharing.active
          text: "Not shown while the screen is shared: it says where you are."
        }
        Repeater {
          model: page.scan && !Sharing.active ? page.scan.near : []

          delegate: Item {
            required property var modelData

            readonly property bool open: modelData.security === ""

            width: parent.width
            height: Style.rowHeight - 8

            Text {
              anchors.verticalCenter: parent.verticalCenter
              anchors.left: parent.left
              anchors.right: wifiSignal.left
              anchors.rightMargin: 8
              text: modelData.ssid
              textFormat: Text.PlainText
              elide: Text.ElideRight
              color: open ? Color.caution : Color.popupText
              font.family: Style.fontFamily
              font.pixelSize: Style.fontSize - 1
            }
            Text {
              id: wifiSignal

              anchors.verticalCenter: parent.verticalCenter
              anchors.right: parent.right
              text: (open ? "open  " : "") + modelData.signal + "%"
              color: open ? Color.caution : Color.popupMuted
              font.family: Style.fontFamily
              font.pixelSize: Style.fontSize - 2
            }
          }
        }
      }
    }
  }
}
