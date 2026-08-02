import QtQuick

Item {
  id: root

  property bool blocked: false

  signal moveRequested(int dx, int dy)
  signal activateRequested()
  signal closeRequested()
  signal tabRequested(int direction)
  signal textKey(string text)

  focus: true
  Keys.priority: Keys.BeforeItem

  function dispatchKey(key, text, modifiers) {
    if (blocked) return false

    if (key === Qt.Key_Escape) {
      closeRequested()
      return true
    }
    if (key === Qt.Key_Tab || key === Qt.Key_Backtab) {
      tabRequested((modifiers & Qt.ShiftModifier) || key === Qt.Key_Backtab ? -1 : 1)
      return true
    }
    if (key === Qt.Key_Down || text === "j") {
      moveRequested(0, 1)
      return true
    }
    if (key === Qt.Key_Up || text === "k") {
      moveRequested(0, -1)
      return true
    }
    if (key === Qt.Key_Right || text === "l") {
      moveRequested(1, 0)
      return true
    }
    if (key === Qt.Key_Left || text === "h") {
      moveRequested(-1, 0)
      return true
    }
    if (key === Qt.Key_Return || key === Qt.Key_Enter || key === Qt.Key_Space) {
      activateRequested()
      return true
    }
    if (text && text.length === 1) {
      textKey(text)
      return true
    }
    return false
  }

  Keys.onPressed: function(event) {
    if (root.dispatchKey(event.key, event.text, event.modifiers)) event.accepted = true
  }
}
