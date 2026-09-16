import QtQuick
import qs.Commons

// A small column per day, for a figure worth comparing across a week rather than reading
// exactly -- tokens burned, in the AI panel.
//
// `maxValue` is passed in rather than taken from `values` so several of these can share one
// scale. Each agent drawn against its own maximum would make a quiet day for one look like a
// busy day for another, which is the comparison the chart exists to make.
//
// The last column is today and is drawn in the full accent; the rest are muted, because today
// is the one still moving. A day with nothing in it keeps a stub on the baseline, so a gap in
// the week reads as a day that happened, not as a missing column.
Item {
  id: root

  property var values: []
  property var labels: []
  property real maxValue: 1

  // The column under the pointer, or -1. Read by whoever wants to explain that day.
  property int hoverIndex: -1

  property int barAreaHeight: 34
  property int spacing: 6

  implicitHeight: barAreaHeight + labelRow.implicitHeight + 4

  Row {
    id: bars

    anchors.left: parent.left
    anchors.right: parent.right
    height: root.barAreaHeight
    spacing: root.spacing

    Repeater {
      model: root.values.length

      delegate: Item {
        id: column

        required property int index
        readonly property bool today: index === root.values.length - 1
        readonly property real value: Number(root.values[index]) || 0

        width: (bars.width - root.spacing * (root.values.length - 1)) / Math.max(1, root.values.length)
        height: bars.height

        Rectangle {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          // At least a stub, so an empty day is still a visible slot.
          height: column.value > 0
            ? Math.max(3, parent.height * Math.min(1, column.value / Math.max(1, root.maxValue)))
            : 2
          radius: Math.min(3, height / 2)
          color: column.value <= 0
            ? Color.popupHover
            : column.today || root.hoverIndex === column.index
              ? Color.popupAccent
              : Qt.rgba(Color.popupAccent.r, Color.popupAccent.g, Color.popupAccent.b, 0.45)
        }

      }
    }
  }

  // One area over the whole chart, columns and labels both, with the day worked out from
  // where the pointer is. Per-column areas left the labels dead -- and the label is exactly
  // where the eye goes to find a day -- and left gaps between columns that flickered the
  // detail back to today on the way across.
  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.NoButton
    onPositionChanged: mouse => {
      var count = root.values.length;
      root.hoverIndex = count > 0 ? Math.max(0, Math.min(count - 1, Math.floor(mouse.x / (width / count)))) : -1;
    }
    onExited: root.hoverIndex = -1
  }

  Row {
    id: labelRow

    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: bars.bottom
    anchors.topMargin: 4
    spacing: root.spacing

    Repeater {
      model: root.labels.length

      delegate: Text {
        required property int index

        width: (labelRow.width - root.spacing * (root.labels.length - 1)) / Math.max(1, root.labels.length)
        horizontalAlignment: Text.AlignHCenter
        text: root.labels[index] || ""
        color: index === root.labels.length - 1 || root.hoverIndex === index ? Color.popupText : Color.popupMuted
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSize - 3
        font.bold: index === root.labels.length - 1
      }
    }
  }
}
