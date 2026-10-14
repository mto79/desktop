import QtQuick
import QtQuick.Layouts
import qs.Commons

// The frame every card on the dashboard shares: what it is about, one figure worth a
// glance, and room underneath.
//
// Cards arrive one after another when their page is shown -- `appear` going true, `order`
// saying which of them this is -- a short rise and fade, each a moment behind the last.
// It is the page settling into place, and it is over in a third of a second.
Rectangle {
  id: card

  property string icon: ""
  property string title: ""
  property string figure: ""
  property color tone: Color.popupText
  property int order: 0
  property bool appear: true
  // A height to keep to, for a card whose list is longer than its share of the page. The
  // list then scrolls inside the card, and the card says so with a fade at its foot. Left
  // at 0, the card is as tall as what is in it.
  property real fixedHeight: 0
  default property alias content: body.data

  Layout.fillWidth: true
  Layout.alignment: Qt.AlignTop
  implicitHeight: fixedHeight > 0 ? fixedHeight : head.implicitHeight + body.implicitHeight + Style.popupPadding * 3
  radius: Style.radius
  color: Color.popupBackground
  border.width: 1
  border.color: hover.hovered ? Qt.rgba(card.tone.r, card.tone.g, card.tone.b, 0.55) : Color.popupBorder

  Behavior on border.color {
    ColorAnimation {
      duration: Style.motionQuick
    }
  }

  HoverHandler {
    id: hover
  }

  opacity: 0
  transform: Translate {
    id: rise

    y: Style.motionTravel / 2
  }

  onAppearChanged: {
    arrive.stop();
    if (appear) {
      arrive.start();
    } else {
      card.opacity = 0;
      rise.y = Style.motionTravel / 2;
    }
  }
  Component.onCompleted: if (appear)
    arrive.start()

  SequentialAnimation {
    id: arrive

    PauseAnimation {
      duration: card.order * 55
    }
    ParallelAnimation {
      NumberAnimation {
        target: card
        property: "opacity"
        to: 1
        duration: Style.motionEnter
        easing.type: Easing.OutCubic
      }
      NumberAnimation {
        target: rise
        property: "y"
        to: 0
        duration: Style.motionEnter
        easing.type: Easing.OutCubic
      }
    }
  }

  RowLayout {
    id: head

    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: Style.popupPadding
    spacing: Style.sectionSpacing

    Text {
      text: card.icon
      color: card.tone
      font.family: Style.fontFamily
      font.pixelSize: Style.iconSize + 4
    }
    Text {
      Layout.fillWidth: true
      textFormat: Text.PlainText
      text: card.title
      color: Color.popupMuted
      font.family: Style.fontFamily
      font.pixelSize: Style.fontSize
      font.weight: Style.barLabelWeight
      font.capitalization: Font.AllUppercase
      elide: Text.ElideRight
    }
    Text {
      text: card.figure
      color: card.tone
      font.family: Style.fontFamily
      font.pixelSize: Style.fontSize + 8
      font.weight: Style.barLabelWeight
    }
  }

  // Whether there is more in the card than it shows.
  readonly property bool scrollable: body.implicitHeight > view.height + 1
  readonly property real furthest: Math.max(0, body.implicitHeight - view.height)

  function scrollTo(position) {
    view.contentY = Math.max(0, Math.min(card.furthest, position));
  }

  // A card's worth, less a row so that the last headline read is still in sight.
  function scrollBy(pages) {
    scrollTo(view.contentY + pages * Math.max(Style.rowHeight, view.height - Style.rowHeight));
  }

  Flickable {
    id: view

    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: head.bottom
    anchors.bottom: parent.bottom
    anchors.margins: Style.popupPadding
    anchors.rightMargin: Style.popupPadding + (card.scrollable ? 8 : 0)
    contentHeight: body.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    // Moved by the wheel, the bar and the arrows below, each of which says where it is
    // going. Dragging the list itself is switched off: it fought the page behind it for
    // the same gesture, and whichever won, it was not the one meant.
    interactive: false

    Behavior on contentY {
      NumberAnimation {
        duration: Style.motionQuick
        easing.type: Easing.OutCubic
      }
    }

    Column {
      id: body

      width: view.width
      spacing: 2
    }
  }

  // The wheel, anywhere on the card, moves the card -- and only the card. A card with
  // nothing more to show leaves the wheel to the page.
  WheelHandler {
    enabled: card.scrollable
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    onWheel: event => card.scrollTo(view.contentY - event.angleDelta.y * 0.9)
  }

  // The bar: how much there is and where you are in it, which a fade at the foot of a
  // list never said. It can be dragged, and clicking above or below it moves a card's worth.
  Rectangle {
    id: track

    visible: card.scrollable
    anchors.right: parent.right
    anchors.rightMargin: 5
    anchors.top: view.top
    anchors.bottom: view.bottom
    width: 5
    radius: width / 2
    color: Qt.rgba(Color.popupText.r, Color.popupText.g, Color.popupText.b, 0.07)

    Rectangle {
      id: thumb

      width: parent.width
      radius: width / 2
      height: Math.max(24, track.height * view.height / Math.max(1, body.implicitHeight))
      y: card.furthest > 0 ? (track.height - height) * view.contentY / card.furthest : 0
      color: grip.pressed || grip.containsMouse ? Color.popupAccent : Qt.rgba(Color.popupText.r, Color.popupText.g, Color.popupText.b, hover.hovered ? 0.45 : 0.25)

      Behavior on color {
        ColorAnimation {
          duration: Style.motionQuick
        }
      }
    }

    MouseArea {
      id: grip

      anchors.fill: parent
      anchors.margins: -6
      hoverEnabled: true
      preventStealing: true

      function follow(mouse) {
        var span = track.height - thumb.height;
        if (span > 0)
          card.scrollTo(card.furthest * (mouse.y - 6 - thumb.height / 2) / span);
      }

      onPressed: mouse => follow(mouse)
      onPositionChanged: mouse => {
        if (pressed)
          follow(mouse);
      }
    }
  }

  // An arrow at the foot when there is more below, and at the head when there is more
  // above: a click on either moves a card's worth that way.
  component More: Rectangle {
    id: more

    property bool down: true
    property bool shown: false
    signal chosen

    anchors.horizontalCenter: view.horizontalCenter
    width: 46
    height: 20
    radius: height / 2
    color: press.containsMouse ? Color.popupSelected : Color.popupBackground
    border.width: 1
    border.color: press.containsMouse ? Color.popupAccent : Color.popupBorder
    opacity: shown ? 1 : 0
    visible: opacity > 0.01

    Behavior on opacity {
      NumberAnimation {
        duration: Style.motionQuick
      }
    }

    Text {
      anchors.centerIn: parent
      text: more.down ? "\u{f0140}" : "\u{f0143}"
      color: press.containsMouse ? Color.popupAccent : Color.popupMuted
      font.family: Style.fontFamily
      font.pixelSize: Style.iconSize
    }

    MouseArea {
      id: press

      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: more.chosen()
    }
  }

  More {
    down: false
    anchors.top: view.top
    anchors.topMargin: -4
    shown: card.scrollable && view.contentY > 2
    onChosen: card.scrollBy(-1)
  }

  More {
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 4
    shown: card.scrollable && view.contentY < card.furthest - 2
    onChosen: card.scrollBy(1)
  }
}
