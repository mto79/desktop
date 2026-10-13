import QtQuick
import qs.Commons

// One of a few: buttons side by side, the chosen one filled in. For a setting that has
// three or four values and deserves to have all of them in sight -- where a row that
// changes on every click only ever shows the one it is on.
//
//   options   [{ id, label, tone?, available?, hint? }]; one that is not available is
//             shown dimmed, and can still be chosen: it is the user's to decide, and
//             the hint says what is missing
//   chosen    the id of the one that is on
//   wanted    the id of the one that was asked for, when that is not the one that is on:
//             a choice that cannot be had right now falls back to another, and the filled
//             button has to be the one in effect. The one asked for keeps an outline in
//             its colour, so it is plain what comes back when it can be had again.
Row {
  id: root

  property var options: []
  property string chosen: ""
  property string wanted: ""
  property int textSize: Style.fontSize
  signal picked(string id)

  spacing: 4

  Repeater {
    model: root.options

    delegate: Rectangle {
      id: button

      required property var modelData

      readonly property bool on: root.chosen === modelData.id
      readonly property bool asked: !on && root.wanted === modelData.id
      readonly property color tone: modelData.tone || Color.popupAccent
      readonly property bool available: modelData.available !== false

      width: name.implicitWidth + Style.popupPadding * 1.6
      height: name.implicitHeight + 10
      radius: height / 2
      color: on ? Qt.rgba(tone.r, tone.g, tone.b, 0.22) : (over.containsMouse ? Color.popupHover : "transparent")
      border.width: on ? 2 : 1
      border.color: on || asked ? tone : Color.popupBorder
      opacity: available || on ? 1 : 0.55

      Behavior on color {
        ColorAnimation {
          duration: Style.motionQuick
        }
      }

      Text {
        id: name

        anchors.centerIn: parent
        text: button.modelData.label
        color: button.on ? button.tone : (over.containsMouse ? Color.popupText : Color.popupMuted)
        font.family: Style.fontFamily
        font.pixelSize: root.textSize
        font.weight: button.on ? Style.barLabelWeight : Font.Normal
      }

      MouseArea {
        id: over

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.picked(button.modelData.id)
      }
    }
  }
}
