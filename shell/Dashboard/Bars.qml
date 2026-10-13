import QtQuick
import qs.Commons

// A row of bars, each with a word under it: a week of days, a handful of categories. The
// bars grow from the floor when the chart appears.
Item {
  id: bars

  // [{label, value}], the name of the field holding the number, and what the tallest
  // bar stands for -- the largest value when left at 0.
  property var values: []
  property string field: "value"
  property real ceiling: 0
  property color tone: Color.popupAccent
  property bool appear: true
  // Many bars and a word under only a few of them: the words are then written at their
  // full width, over the neighbours' empty places, where a slot's own width would cut
  // "12 Oct" down to "1…".
  property bool sparse: false
  readonly property real gap: sparse ? 4 : 8
  // The bar to draw in full colour, by index; the rest are quieter. -1 for none.
  property int highlight: -1

  readonly property real tallest: {
    var most = ceiling;
    for (var i = 0; i < values.length; i++)
      most = Math.max(most, Number(values[i][field]) || 0);
    return most > 0 ? most : 1;
  }

  implicitHeight: 120

  Row {
    anchors.fill: parent
    spacing: bars.gap

    Repeater {
      model: bars.values

      delegate: Item {
        id: slot

        required property var modelData
        required property int index

        readonly property real amount: Number(modelData[bars.field]) || 0

        width: (bars.width - bars.gap * (bars.values.length - 1)) / Math.max(1, bars.values.length)
        height: bars.height

        Rectangle {
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.bottom: name.top
          anchors.bottomMargin: 6
          width: Math.min(parent.width, 34)
          radius: 4
          color: bars.tone
          opacity: (bars.highlight === -1 || bars.highlight === slot.index) ? 0.9 : 0.4
          height: bars.appear ? Math.max(slot.amount > 0 ? 3 : 1, (bars.height - name.height - 6) * slot.amount / bars.tallest) : 1

          Behavior on height {
            NumberAnimation {
              duration: 500 + slot.index * 40
              easing.type: Easing.OutCubic
            }
          }
        }

        Text {
          id: name

          // Under the first bar a wide word starts at the edge; centred it would lose
          // its first letters to the card.
          anchors.horizontalCenter: bars.sparse && slot.index === 0 ? undefined : parent.horizontalCenter
          anchors.bottom: parent.bottom
          width: bars.sparse ? implicitWidth : parent.width
          horizontalAlignment: Text.AlignHCenter
          elide: bars.sparse ? Text.ElideNone : Text.ElideRight
          text: slot.modelData.label !== undefined ? slot.modelData.label : (slot.modelData.day || slot.modelData.name || "")
          color: Color.popupMuted
          font.family: Style.fontFamily
          font.pixelSize: Style.fontSize - 2
        }
      }
    }
  }
}
