import QtQuick
import qs.Commons

// A row of level bars with falling peak caps: the bar's equalizer, and the one on the
// now-playing card.
//
// Each bar is a window onto a gradient the full height of the row, so a bar only turns
// to the top colour when it reaches the top -- a gradient drawn per bar would put the
// same pink on a whisper as on a peak. The caps hold the highest recent level and fall
// back slowly, which is what makes it read as an equalizer rather than as a bar chart.
Item {
  id: root

  // Levels from 0 to 1, as Spectrum hands them over. Fewer than `count` leaves the
  // rest at rest; an empty list lays every bar down.
  property var levels: []
  property int count: 12
  property int barWidth: 3
  property int spacing: 2
  property color colorLow: Color.barAccent
  property color colorHigh: Color.barUrgent
  // How far a cap falls per frame, as a fraction of the height.
  property real peakFall: 0.025
  property bool peaks: true

  // Even at rest every bar shows a sliver: a flat line says "here, but quiet", where
  // nothing at all would read as the widget having gone.
  readonly property real floor: 2

  implicitWidth: count * barWidth + (count - 1) * spacing
  implicitHeight: 18

  Row {
    anchors.fill: parent
    spacing: root.spacing

    Repeater {
      model: root.count

      delegate: Item {
        id: bar

        required property int index

        readonly property real level: index < root.levels.length ? root.levels[index] : 0
        property real peak: 0

        // Stopped, the caps drop with the bars: one left hanging would say there is sound.
        onLevelChanged: peak = root.levels.length === 0 ? 0 : (level > peak ? level : Math.max(0, peak - root.peakFall))

        width: root.barWidth
        height: root.height

        Item {
          id: fill

          anchors.bottom: parent.bottom
          width: parent.width
          height: Math.max(root.floor, Math.round(bar.level * root.height))
          clip: true

          Behavior on height {
            NumberAnimation {
              duration: 70
              easing.type: Easing.OutQuad
            }
          }

          Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: root.height
            radius: width / 2

            gradient: Gradient {
              GradientStop {
                position: 0
                color: root.colorHigh
              }
              GradientStop {
                position: 1
                color: root.colorLow
              }
            }
          }
        }

        Rectangle {
          visible: root.peaks && bar.peak > 0.04
          width: parent.width
          height: 1
          y: Math.round(root.height - bar.peak * root.height) - 2
          color: root.colorHigh
          opacity: 0.85

          Behavior on y {
            NumberAnimation {
              duration: 90
            }
          }
        }
      }
    }
  }
}
