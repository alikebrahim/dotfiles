import QtQuick
import Quickshell
import ui as Ui

ShellRoot {
  id: root

  readonly property string resultPath: Quickshell.env("QUATTRO_QS_TEST_RESULT")
  property var failures: []
  property int moves: 0
  property int activations: 0
  property int closes: 0

  Ui.X11Panel {
    id: passivePanel
    panelSize: 32
    reserveSpace: true
    visible: true
  }

  Ui.PopupCard {
    id: popup
    open: true
    cardWidth: 320
    cardHeight: 180
  }

  Ui.KeyboardNavigator {
    id: navigator
    onMoveRequested: function(dx, dy) { root.moves += Math.abs(dx) + Math.abs(dy) }
    onActivateRequested: root.activations++
    onCloseRequested: root.closes++
  }

  function expect(condition, message) {
    if (!condition) failures.push(String(message))
  }

  function shellQuote(value) {
    return "'" + String(value).replace(/'/g, "'\\''") + "'"
  }

  function writeResult() {
    var payload = JSON.stringify({
      ok: failures.length === 0,
      failures: failures,
      passiveExclusiveZone: passivePanel.exclusiveZone,
      popupExclusiveZone: popup.exclusiveZone,
      popupFocusable: popup.focusable,
      moves: moves,
      activations: activations,
      closes: closes
    })
    Quickshell.execDetached([
      "bash",
      "-lc",
      "printf '%s' " + shellQuote(payload) + " > " + shellQuote(resultPath)
    ])
  }

  Timer {
    interval: 50
    running: true
    repeat: false
    onTriggered: {
      root.expect(passivePanel.exclusiveZone === 32, "passive panel reserves its configured workarea")
      root.expect(popup.exclusiveZone === 0, "popup does not reserve workarea")
      root.expect(popup.focusable, "popup is focusable")
      root.expect(navigator.dispatchKey(Qt.Key_Down, "", 0), "down is handled")
      root.expect(navigator.dispatchKey(Qt.Key_K, "k", 0), "k is handled")
      root.expect(navigator.dispatchKey(Qt.Key_Return, "", 0), "return is handled")
      root.expect(navigator.dispatchKey(Qt.Key_Escape, "", 0), "escape is handled")
      root.expect(root.moves === 2, "arrow and hjkl dispatch movement")
      root.expect(root.activations === 1, "enter dispatches activation")
      root.expect(root.closes === 1, "escape dispatches close")
      root.writeResult()
    }
  }

  Timer {
    interval: 1500
    running: true
    repeat: false
    onTriggered: Qt.quit()
  }
}
