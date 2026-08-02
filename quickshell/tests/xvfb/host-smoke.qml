import QtQuick
import Quickshell
import services as Services

ShellRoot {
  id: root

  readonly property string resultPath: Quickshell.env("QUATTRO_QS_TEST_RESULT")

  Services.ShellState {
    id: shellState
  }

  function shellQuote(value) {
    return "'" + String(value).replace(/'/g, "'\\''") + "'"
  }

  function writeResult(payload) {
    if (!resultPath) return
    Quickshell.execDetached([
      "bash",
      "-lc",
      "printf '%s' " + shellQuote(JSON.stringify(payload)) + " > " + shellQuote(resultPath)
    ])
  }

  Timer {
    interval: 1
    running: true
    repeat: false
    onTriggered: {
      root.writeResult({
        ok: shellState.ready,
        resident: shellState.resident,
        barVisible: shellState.barVisible
      })
      Qt.callLater(Qt.quit)
    }
  }
}
