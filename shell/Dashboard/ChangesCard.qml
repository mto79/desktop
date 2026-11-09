import QtQuick
import qs.Commons

// What came and went between scans, newest first: a device never seen before on this
// network, one back after missing a scan, one that was there last time and is not now.
// From desktop-scan-changes, which keeps the log; see there for why a quiet scan after a
// sweep reports nothing as gone, and why Bluetooth's random addresses are left out.
Card {
  id: card

  property var events: []
  // The latest scan's own changes, for the line at the top: {new, back, gone, first}.
  property var latest: null
  property string nothing: ""

  title: "Came and went"
  icon: "\u{f02da}"
  figure: events.length > 0 ? String(events.length) : ""
  tone: Color.popupAccent
  fixedHeight: Math.min(360, implicitHeightFor(events.length))

  function implicitHeightFor(count) {
    return 110 + Math.min(count, 10) * (Style.rowHeight + 4);
  }

  function ago(stamp) {
    var s = Math.max(0, Math.round(Date.now() / 1000 - stamp));
    if (s < 90)
      return "just now";
    if (s < 5400)
      return Math.round(s / 60) + " min ago";
    if (s < 86400 * 2)
      return Math.round(s / 3600) + " h ago";
    return Qt.formatDateTime(new Date(stamp * 1000), "d MMM HH:mm");
  }

  readonly property var looks: ({
      "new": {
        glyph: "\u{f0415}",
        word: "new",
        tone: Color.caution
      },
      "back": {
        glyph: "\u{f0450}",
        word: "back",
        tone: Color.popupAccent
      },
      "gone": {
        glyph: "\u{f0374}",
        word: "gone",
        tone: Color.popupMuted
      }
    })

  Quiet {
    visible: Sharing.active
    text: "Hidden while the screen is shared: the names and addresses of what is around you."
  }

  Quiet {
    visible: !Sharing.active && !!card.latest
    text: {
      var l = card.latest;
      if (!l)
        return "";
      if (l.first)
        return "First scan here: what was found is remembered, and the next scan says what changed.";
      var parts = [];
      if (l.new.length)
        parts.push(l.new.length + " new");
      if (l.back.length)
        parts.push(l.back.length + " back");
      if (l.gone.length)
        parts.push(l.gone.length + " gone");
      return parts.length ? parts.join("  ·  ") + " since the scan before" : "Nothing changed since the scan before.";
    }
  }

  Repeater {
    model: Sharing.active ? [] : card.events

    delegate: Item {
      required property var modelData

      readonly property var look: card.looks[modelData.event] || card.looks["new"]

      width: parent.width
      height: Style.rowHeight + 4

      Text {
        id: mark

        anchors.verticalCenter: parent.verticalCenter
        width: 22
        text: look.glyph
        color: look.tone
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSize + 1
      }
      Column {
        anchors.left: mark.right
        anchors.leftMargin: 6
        anchors.right: when.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter

        Text {
          width: parent.width
          text: modelData.label + "  ·  " + look.word
          textFormat: Text.PlainText
          elide: Text.ElideRight
          color: Color.popupText
          font.family: Style.fontFamily
          font.pixelSize: Style.fontSize - 1
        }
        Text {
          width: parent.width
          text: modelData.detail || ""
          textFormat: Text.PlainText
          elide: Text.ElideRight
          color: Color.popupMuted
          font.family: Style.fontFamily
          font.pixelSize: Style.fontSize - 3
        }
      }
      Text {
        id: when

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: card.ago(modelData.at)
        color: Color.popupMuted
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSize - 2
      }
    }
  }

  Quiet {
    visible: !Sharing.active && card.events.length === 0
    text: card.nothing
  }
}
