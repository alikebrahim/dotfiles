import QtQuick
import Quickshell
import services as Services
import modules.bar as Bar

ShellRoot {
  id: root

  readonly property string resultPath: Quickshell.env("QUATTRO_QS_TEST_RESULT")
  property var failures: []

  Services.ShellState { id: shellState }
  Services.AwesomeBridge { id: bridge }

  Bar.PrimaryBar {
    id: bar
    shellState: shellState
    bridge: bridge
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
      resolvedOutputId: bar.resolvedOutputId,
      screenName: bar.screen ? bar.screen.name : "",
      focusedScreenName: bar.focusedScreen ? bar.focusedScreen.name : "",
      controlPopupScreenName: bar.controlPopupScreen ? bar.controlPopupScreen.name : "",
      controlsScreenName: bar.systemControls.screen ? bar.systemControls.screen.name : "",
      barSurfaceCount: bar.surfaceCount,
      continuousBackground: bar.color.a > 0,
      tagCount: bar.tagCount,
      focusedTitle: bar.focusedTitle,
      clockText: bar.clockText,
      visible: bar.visible,
      exclusiveZone: bar.exclusiveZone
    })
    Quickshell.execDetached([
      "bash",
      "-lc",
      "printf '%s' " + shellQuote(payload) + " > " + shellQuote(resultPath)
    ])
  }

  Component.onCompleted: {
    var primaryScreenName = Quickshell.screens.length > 0 ? Quickshell.screens[0].name : ""
    var focusedScreenName = Quickshell.screens.length > 1 ? Quickshell.screens[1].name : ""
    bridge.applyRaw(JSON.stringify({
      primaryOutput: "declared-primary",
      focusedOutput: "declared-secondary",
      outputs: [
        { id: "declared-secondary", name: focusedScreenName },
        { id: "declared-primary", name: primaryScreenName }
      ],
      tags: [
        { name: "1", selected: true, occupied: true, urgent: false },
        { name: "2", selected: false, occupied: false, urgent: true }
      ],
      focusedClient: {
        title: "Bridge-selected title",
        class: "example",
        screen: "declared-secondary"
      }
    }))
  }

  Timer {
    interval: 100
    running: true
    repeat: false
    onTriggered: {
      root.expect(bar.resolvedOutputId === "declared-primary", "bridge primary output is selected")
      root.expect(bar.screen === Quickshell.screens[0], "primary output maps to the matching X11 screen")
      root.expect(bar.controlPopupScreen !== undefined && bar.controlPopupScreen === bar.resolvedScreen
        && bar.systemControls.screen === bar.controlPopupScreen,
        "control popouts consume an explicit bar-owned screen instead of the focused-client screen")
      root.expect(bar.surfaceCount === 1, "only one bar surface exists")
      root.expect(bar.color.a > 0, "bar uses one continuous Omarchy background surface")
      root.expect(bar.panelSize === 26, "bar uses Omarchy's horizontal size token")
      root.expect(bar.tagCount === 2, "Awesome tags are rendered")
      root.expect(bar.focusedTitle === "Bridge-selected title", "focused title comes from the bridge")
      root.expect(bar.clockText.length > 0, "clock renders text")
      root.expect(bar.visible && bar.exclusiveZone === bar.panelSize, "shown bar maps and reserves workarea")

      bar.visibilityController.toggle()
      Qt.callLater(function() {
        root.expect(!bar.visible && bar.exclusiveZone === 0, "hidden bar unmaps and releases workarea")
        root.expect(shellState.resident, "shell remains resident while the bar is hidden")
        bar.visibilityController.toggle()
        Qt.callLater(function() {
          root.expect(bar.visible && bar.exclusiveZone === bar.panelSize, "shown bar restores workarea")
          root.writeResult()
          Qt.callLater(Qt.quit)
        })
      })
    }
  }
}
