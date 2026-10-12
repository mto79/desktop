import QtQuick
import qs.Commons

// One number, large, with what it counts under it. It counts up to its value when it
// appears and whenever the value changes -- a moment of movement that says "this was just
// read", where a number that simply sat there could be an hour old.
Column {
  id: figure

  property real value: 0
  property int decimals: 0
  property string prefix: ""
  property string unit: ""
  property string label: ""
  property color tone: Color.popupText
  property bool appear: true

  property real shown: 0

  spacing: 2

  function run() {
    count.stop();
    count.from = 0;
    count.to = value;
    count.start();
  }

  onValueChanged: run()
  onAppearChanged: if (appear)
    run()

  NumberAnimation {
    id: count

    target: figure
    property: "shown"
    duration: 600
    easing.type: Easing.OutCubic
  }

  Row {
    spacing: 4

    Text {
      text: figure.prefix + figure.shown.toFixed(figure.decimals)
      color: figure.tone
      font.family: Style.fontFamily
      font.pixelSize: Style.fontSize + 16
      font.weight: Font.Light
    }
    Text {
      anchors.baseline: parent.children[0].baseline
      text: figure.unit
      color: Color.popupMuted
      font.family: Style.fontFamily
      font.pixelSize: Style.fontSize + 1
    }
  }
  Text {
    text: figure.label
    color: Color.popupMuted
    font.family: Style.fontFamily
    font.pixelSize: Style.fontSize - 1
    font.capitalization: Font.AllUppercase
  }
}
