import QtQuick
import qs.Commons

// A single-line field for a panel: the passphrase box, and whatever else needs typing
// later. Panels hold keyboard focus while open, so this is somewhere for that focus to
// land -- which is the whole reason the panels moved off xdg_popup.
Rectangle {
  id: root

  property alias text: input.text
  property alias echoMode: input.echoMode
  property string placeholder: ""

  signal accepted
  signal cancelled

  function take() {
    input.forceActiveFocus();
    input.selectAll();
  }

  // Giving focus back to the panel is not enough on its own: the enclosing FocusScope
  // remembers this field as its focused child and hands it straight back. Dropping the
  // field's own focus flag first is what actually releases the keyboard.
  function release() {
    input.focus = false;
  }

  implicitHeight: Style.rowHeight
  radius: Style.radius
  color: Color.popupBackground
  border.width: 1
  border.color: input.activeFocus ? Color.popupAccent : Color.popupBorder

  Text {
    anchors.fill: parent
    anchors.leftMargin: 8
    verticalAlignment: Text.AlignVCenter
    visible: input.text === ""
    text: root.placeholder
    color: Color.popupMuted
    font.family: Style.fontFamily
    font.pixelSize: Style.fontSize
    elide: Text.ElideRight
  }

  TextInput {
    id: input

    anchors.fill: parent
    anchors.leftMargin: 8
    anchors.rightMargin: 8
    verticalAlignment: Text.AlignVCenter
    color: Color.popupText
    font.family: Style.fontFamily
    font.pixelSize: Style.fontSize
    selectionColor: Color.popupSelected
    selectedTextColor: Color.popupText
    clip: true

    onAccepted: root.accepted()
    // Escape belongs to the field while it has focus: it cancels the prompt rather
    // than closing the whole panel out from under it.
    Keys.onEscapePressed: event => {
      event.accepted = true;
      root.cancelled();
    }
  }
}
