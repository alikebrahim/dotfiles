import QtQuick
import Quickshell
import Quickshell.Io
import services as Services
import modules.bar as Bar

ShellRoot {
  id: root

  readonly property string resultPath: Quickshell.env("QUATTRO_QS_TEST_RESULT")

  Services.ShellState { id: shellState }
  Services.AwesomeBridge { id: bridge }

  Bar.PrimaryBar {
    id: bar
    shellState: shellState
    bridge: bridge
  }

  IpcHandler {
    target: "shell"
    function ping(): string { return "ok" }
  }

  IpcHandler {
    target: "bar"
    function status(): string { return bar.visible ? "shown" : "hidden" }
    function toggleVisibility(): string {
      bar.visibilityController.toggle()
      return bar.visible ? "shown" : "hidden"
    }
  }

  function shellQuote(value) {
    return "'" + String(value).replace(/'/g, "'\\''") + "'"
  }

  function writeReady() {
    var payload = JSON.stringify({
      ok: bridge.ready && bar.visible && bar.exclusiveZone === bar.panelSize,
      screenName: bar.screen ? bar.screen.name : "",
      exclusiveZone: bar.exclusiveZone,
      resident: shellState.resident
    })
    Quickshell.execDetached([
      "bash",
      "-lc",
      "printf '%s' " + shellQuote(payload) + " > " + shellQuote(resultPath)
    ])
  }

  Component.onCompleted: {
    var screenName = Quickshell.screens.length > 0 ? Quickshell.screens[0].name : ""
    bridge.applyRaw(JSON.stringify({
      primaryOutput: "ipc-primary",
      focusedOutput: "ipc-primary",
      outputs: [{ id: "ipc-primary", name: screenName }],
      tags: [{ name: "1", selected: true, occupied: true, urgent: false }],
      focusedClient: { title: "IPC visibility proof", class: "quickshell", screen: "ipc-primary" }
    }))
  }

  Timer {
    interval: 100
    running: true
    repeat: false
    onTriggered: root.writeReady()
  }

  Timer {
    interval: 60000
    running: true
    repeat: false
    onTriggered: Qt.quit()
  }
}
