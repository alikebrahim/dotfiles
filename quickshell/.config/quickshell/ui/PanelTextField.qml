import QtQuick
import "../style" as ShellStyle

// Compact, theme-native inline editor for panel actions such as Wi-Fi PSKs.
// The caller owns the value; this component never logs or persists its text.
Item {
  id: root

  property alias text: editor.text
  property string placeholderText: ""
  property string accessibleName: placeholderText || "Text field"
  property bool password: false
  signal accepted()
  signal cancelled()

  implicitHeight: ShellStyle.Metrics.controlHeight
  opacity: enabled ? 1 : 0.42

  function focusEditor() {
    editor.forceActiveFocus(Qt.ShortcutFocusReason)
  }

  Rectangle {
    anchors.fill: parent
    radius: ShellStyle.Metrics.cornerRadius
    color: ShellStyle.Palette.normalWash
    border.width: 1
    border.color: editor.activeFocus
      ? ShellStyle.Palette.panelBorder
      : ShellStyle.Palette.controlBorder
  }

  Text {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.leftMargin: ShellStyle.Metrics.controlPaddingX
    anchors.rightMargin: ShellStyle.Metrics.controlPaddingX
    anchors.verticalCenter: parent.verticalCenter
    visible: editor.text.length === 0 && !editor.activeFocus
    text: root.placeholderText
    textFormat: Text.PlainText
    color: ShellStyle.Palette.muted
    elide: Text.ElideRight
    font.family: ShellStyle.Metrics.fontFamily
    font.pixelSize: ShellStyle.Metrics.bodySmallSize
  }

  TextInput {
    id: editor
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.leftMargin: ShellStyle.Metrics.controlPaddingX
    anchors.rightMargin: ShellStyle.Metrics.controlPaddingX
    anchors.verticalCenter: parent.verticalCenter
    enabled: root.enabled
    clip: true
    selectByMouse: true
    color: ShellStyle.Palette.foreground
    selectionColor: ShellStyle.Palette.selectedWash
    selectedTextColor: ShellStyle.Palette.foreground
    font.family: ShellStyle.Metrics.fontFamily
    font.pixelSize: ShellStyle.Metrics.bodySize
    echoMode: root.password ? TextInput.Password : TextInput.Normal
    passwordCharacter: "•"
    Accessible.role: Accessible.EditableText
    Accessible.name: root.accessibleName

    Keys.onReturnPressed: function(event) {
      root.accepted()
      event.accepted = true
    }
    Keys.onEnterPressed: function(event) {
      root.accepted()
      event.accepted = true
    }
    Keys.onEscapePressed: function(event) {
      root.cancelled()
      event.accepted = true
    }
  }

  TapHandler {
    enabled: root.enabled
    acceptedButtons: Qt.LeftButton
    onTapped: root.focusEditor()
  }
}
