import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import qs.Ui

// A small sign that the desktop is talking, and what it is saying.
//
// A voice with nothing to look at is a voice from nowhere: it starts, you look up, and
// there is no telling what is speaking, whether it has finished, or what the half you
// missed was. So while desktop-say has the floor a small card sits in the corner of the
// screen -- a core that pulses with a ring turning round it, and the line being said
// beside it -- and goes when the line has been said.
//
// Small, in the corner, and it takes no clicks and no keys: it is there to be glanced at,
// and whatever is under it stays usable. The voice is the interruption; this is only the
// answer to "what was that?".
//
// It follows a file desktop-say keeps for as long as it has something to show
// ($XDG_RUNTIME_DIR/desktop/say/now), so nothing has to be running in the shell for
// speech to work, and speech does not depend on the shell being up.
Item {
  id: root

  // Not while the dashboard is in front: it has the same thing, larger, and two of them
  // saying one sentence is one too many.
  readonly property bool onDashboard: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === 6
  readonly property bool active: Speech.active && !onDashboard

  ScreenSurface {
    visible: root.active || card.opacity > 0.01
    surfaceNamespace: "desktop-voice"
    position: "bottom-right"
    margin: Style.voiceMargin
    // On the screen you are looking at; the others are left alone.
    screen: {
      var focused = Hyprland.focusedMonitor;
      for (var i = 0; i < Quickshell.screens.length; i++)
        if (focused && Quickshell.screens[i].name === focused.name)
          return Quickshell.screens[i];
      return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
    }

    Rectangle {
      id: card

      width: Style.voiceWidth
      height: Math.max(orb.height, caption.implicitHeight) + Style.popupPadding * 2
      radius: Style.radius
      color: Qt.rgba(Color.popupBackground.r, Color.popupBackground.g, Color.popupBackground.b, 0.92)
      border.width: 1
      border.color: Color.popupBorder

      opacity: root.active ? 1 : 0

      Behavior on opacity {
        NumberAnimation {
          duration: Style.motionEnter
          easing.type: Easing.OutCubic
        }
      }

      Orb {
        id: orb

        anchors.left: parent.left
        anchors.leftMargin: Style.popupPadding
        anchors.verticalCenter: parent.verticalCenter
        width: Style.voiceOrbSize
        height: width
        awake: Speech.active
        lively: Speech.lively
        listening: Speech.listening
        running: root.active
      }

      Text {
        id: caption

        anchors.left: orb.right
        anchors.leftMargin: Style.popupPadding
        anchors.right: parent.right
        anchors.rightMargin: Style.popupPadding
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -7
        text: Speech.line
        textFormat: Text.PlainText
        color: Speech.lively ? Color.popupText : Color.popupMuted
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSize - 1
        wrapMode: Text.WordWrap
        maximumLineCount: 2
        elide: Text.ElideRight
      }

      // Which model hears what the list does not know -- and whether that is here.
      Text {
        anchors.left: caption.left
        anchors.right: caption.right
        anchors.top: caption.bottom
        anchors.topMargin: 3
        text: Speech.modelLine
        textFormat: Text.PlainText
        color: Speech.modelWhere === "cloud" ? Color.popupUrgent : Speech.modelWhere === "remote" ? Color.caution : Color.popupMuted
        opacity: 0.8
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSize - 4
        elide: Text.ElideRight
      }
    }
  }
}
