import QtQuick
import QtQuick.Layouts
import qs.Commons

// A nerd-font glyph with optional text beside it. The two are sized independently:
// glyphs in most nerd fonts render a touch small next to text at the same point size.
RowLayout {
  id: root

  property string icon: ""
  property string text: ""
  property color color: Color.barText
  // The glyph on its own, for a widget whose icon says something its text does not --
  // the Wi-Fi ramp coloured by signal, beside a speed that is not.
  property color iconColor: root.color
  property int iconSize: Style.iconSize
  property int fontSize: Style.fontSize

  // In use right now: the microphone being listened to, sound playing, a download
  // running. The glyph gets a soft light behind it that breathes, in its own colour --
  // the bar's answer to the AI orb waking up. It says "working", where dimming the whole
  // module (CommandWidget's pulse) says "look here", so the two do not mean the same.
  // Whether something is in use is the widget's to know; what that looks like is here,
  // once, so every icon on the bar does it the same way.
  property bool lively: false

  // Set by the bar when the section this sits in has run out of room: the text goes and
  // the glyph stays. A label with no glyph has nothing to fall back to, so it is left be.
  property bool compact: false
  // What is left of the text when compact, for a widget whose number is the point and the
  // rest decoration: the CPU's history graph goes and its percentage stays. Without one
  // the text goes altogether.
  property string shortText: ""
  readonly property bool shortened: root.compact && root.icon !== "" && root.shortText !== ""
  readonly property bool textShown: root.text !== "" && !(root.compact && root.icon !== "" && root.shortText === "")
  // What going compact gives back. Measured rather than read off the label, whose text is
  // the short one while compact -- so this does not move when `compact` does, and the bar
  // can add it back to work out what the section would need at full size.
  readonly property real compactSaving: {
    if (root.icon === "" || root.text === "")
      return 0;
    if (root.shortText !== "")
      return Math.max(0, full.advanceWidth - brief.advanceWidth);
    return full.advanceWidth + 6;
  }

  spacing: root.icon !== "" && root.textShown ? 6 : 0

  Text {
    id: glyph

    visible: root.icon !== ""
    text: root.icon
    color: root.iconColor
    font.family: Style.fontFamily
    font.pixelSize: root.iconSize
    verticalAlignment: Text.AlignVCenter

    Behavior on color {
      ColorAnimation {
        duration: Style.motionEnter
      }
    }

    Rectangle {
      id: glow

      readonly property bool on: root.lively && glyph.visible && root.visible

      z: -1
      anchors.centerIn: parent
      width: root.iconSize * 1.7
      height: width
      radius: width / 2
      color: root.color
      visible: opacity > 0
      opacity: 0

      // Up and down for as long as it lasts, and out when it stops: a light left
      // half-lit would say something is still going on.
      SequentialAnimation {
        running: glow.on
        loops: Animation.Infinite

        ParallelAnimation {
          NumberAnimation {
            target: glow
            property: "opacity"
            to: 0.34
            duration: Style.motionBreath
            easing.type: Easing.InOutSine
          }
          NumberAnimation {
            target: glow
            property: "scale"
            to: 1.0
            duration: Style.motionBreath
            easing.type: Easing.InOutSine
          }
        }
        ParallelAnimation {
          NumberAnimation {
            target: glow
            property: "opacity"
            to: 0.1
            duration: Style.motionBreath
            easing.type: Easing.InOutSine
          }
          NumberAnimation {
            target: glow
            property: "scale"
            to: 0.7
            duration: Style.motionBreath
            easing.type: Easing.InOutSine
          }
        }
      }
      NumberAnimation {
        target: glow
        property: "opacity"
        running: !glow.on
        to: 0
        duration: Style.motionEnter
      }
    }
  }

  TextMetrics {
    id: full

    text: root.text
    font: label.font
  }

  TextMetrics {
    id: brief

    text: root.shortText
    font: label.font
  }

  Text {
    id: label

    visible: root.textShown
    text: root.shortened ? root.shortText : root.text
    color: root.color
    font.family: Style.fontFamily
    font.pixelSize: root.fontSize
    verticalAlignment: Text.AlignVCenter
  }
}
