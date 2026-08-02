import QtQuick
import Quickshell
import services as Services
import modules.bar as Bar

ShellRoot {
  id: root

  readonly property string resultPath: Quickshell.env("QUICKSHELL_QS_TEST_RESULT")
  readonly property bool holdOpen: Quickshell.env("QUICKSHELL_TAILSCALE_TEST_HOLD") === "1"
  property var failures: []
  property int stage: 0

  function peer(id, name, ip, online, os, exitOption, activeExit) {
    return {
      ID: id,
      HostName: name,
      DNSName: name + ".fixture.ts.net.",
      TailscaleIPs: [ip],
      Online: online,
      Active: online,
      OS: os,
      ExitNodeOption: exitOption === true,
      ExitNode: activeExit === true
    }
  }

  function statusJson(state, chosenExit) {
    return JSON.stringify({
      BackendState: state,
      CurrentTailnet: { Name: "fixture.example" },
      Self: {
        ID: "self",
        HostName: "fixture-host",
        DNSName: "fixture-host.fixture.ts.net.",
        TailscaleIPs: ["100.64.0.1"],
        Online: state === "Running",
        OS: "linux"
      },
      Peer: {
        "peer-exit": peer("peer-exit", "exit-box", "100.64.0.9", true, "linux", true, chosenExit === true),
        "peer-a": peer("peer-a", "alpha", "100.64.0.2", true, "linux", false, false),
        "peer-b": peer("peer-b", "beta", "100.64.0.3", true, "windows", false, false),
        "peer-c": peer("peer-c", "charlie", "100.64.0.4", false, "android", false, false),
        "peer-d": peer("peer-d", "delta", "100.64.0.5", false, "linux", false, false),
        "peer-e": peer("peer-e", "echo", "100.64.0.6", false, "linux", false, false),
        "peer-f": peer("peer-f", "foxtrot", "100.64.0.7", false, "linux", false, false)
      },
      Health: []
    })
  }

  Services.ShellState { id: shellState }
  Services.AwesomeBridge { id: bridge }
  Services.CommandTransport {
    id: transport
    fixtureMode: true
    allowMutations: false
    fixtureResponses: ({ "tailscale.status": root.statusJson("Running", false) })
  }
  Services.ModalController { id: modalController }
  Services.BarPopoutController {
    id: popoutController
    modalController: modalController
  }
  Services.TailscaleService {
    id: tailscaleService
    transport: transport
    refreshOnStart: false
    refreshInterval: 0
    actionTimeoutMs: 1200
    maxPeers: 5
  }
  QtObject {
    id: fakeClipboard
    property string lastText: ""
    property string lastLabel: ""
    function copyText(value, label) {
      lastText = String(value || "")
      lastLabel = String(label || "")
      return lastText !== ""
    }
  }

  Bar.PrimaryBar {
    id: bar
    shellState: shellState
    bridge: bridge
    tailscaleService: tailscaleService
    clipboardService: fakeClipboard
    modalController: modalController
    barPopoutController: popoutController
  }

  function expect(condition, message) {
    if (!condition) failures.push(String(message))
  }

  function commandRecorded(suffix, expected) {
    for (var i = 0; i < transport.recordedActions.length; i++) {
      var action = transport.recordedActions[i]
      if (action.key === "tailscale.action." + suffix
          && JSON.stringify(action.command) === JSON.stringify(expected)) return true
    }
    return false
  }

  function shellQuote(value) {
    return "'" + String(value).replace(/'/g, "'\\''") + "'"
  }

  function writeResult() {
    var payload = JSON.stringify({
      ok: failures.length === 0,
      failures: failures,
      peerCount: tailscaleService.peerCount,
      onlinePeerCount: tailscaleService.onlinePeerCount,
      popupOpen: bar.tailscaleWidget.popupOpen,
      popupWidth: bar.tailscaleWidget.panel.width,
      popupHeight: bar.tailscaleWidget.panel.height,
      recordedActions: transport.recordedActions,
      clipboardText: fakeClipboard.lastText,
      activePopout: popoutController.activePopout
    })
    Quickshell.execDetached([
      "/usr/bin/bash", "-c",
      "printf '%s' \"$1\" > \"$2\"",
      "tailscale-fixture", payload, resultPath
    ])
  }

  function finish() {
    transport.allowMutations = false
    tailscaleService.applyStatus(statusJson("Running", false))
    expect(tailscaleService.pendingAction === "", "no action remains pending")
    expect(tailscaleService.currentExitNodeKey === "", "exit-node clear converged")
    expect(commandRecorded("exit-clear", ["/usr/sbin/tailscale", "set", "--exit-node="]),
      "exit-node clear uses exact argv")

    if (holdOpen) {
      bar.tailscaleWidget.openPopup()
      Qt.callLater(writeResult)
      return
    }
    bar.tailscaleWidget.closePopup()
    expect(popoutController.activePopout === "", "close releases popout ownership")
    writeResult()
    quitDelay.restart()
  }

  Component.onCompleted: {
    var screenName = Quickshell.screens.length > 0 ? Quickshell.screens[0].name : ""
    bridge.applyRaw(JSON.stringify({
      primaryOutput: "fixture-primary",
      focusedOutput: "fixture-primary",
      outputs: [{ id: "fixture-primary", name: screenName }],
      tags: [{ name: "1", selected: true, occupied: true, urgent: false }],
      focusedClient: { title: "Tailscale fixture", class: "fixture", screen: "fixture-primary" }
    }))
    tailscaleService.applyStatus(statusJson("Running", false))
    sequence.restart()
  }

  Timer {
    id: sequence
    interval: 120
    repeat: true
    onTriggered: {
      if (root.stage === 0) {
        root.expect(tailscaleService.installed && tailscaleService.connected,
          "valid status establishes running state")
        root.expect(tailscaleService.peerCount === 5,
          "peer snapshots obey the total cap")
        root.expect(tailscaleService.onlinePeerCount === 3,
          "online peer count is reduced correctly")
        root.expect(tailscaleService.exitNodes.length === 1,
          "exit-node options are retained inside the cap")

        var firstKey = tailscaleService.peers[0].key
        tailscaleService.applyStatus("{broken")
        root.expect(tailscaleService.stale && tailscaleService.peerCount === 5,
          "malformed status preserves the last good snapshot")
        root.expect(tailscaleService.peers[0].key === firstKey,
          "malformed status preserves peer identity")
        tailscaleService.applyStatus(statusJson("Running", false))

        root.expect(bar.tailscaleWidget.openPopup(), "panel opens on the fixture screen")
        root.expect(popoutController.activePopout === "tailscale",
          "panel owns the bar popout controller")
        root.expect(bar.tailscaleWidget.panel.width === 380,
          "panel width is bounded")
        root.expect(bar.tailscaleWidget.activateIndex(1),
          "peer activation routes to clipboard service")
        root.expect(fakeClipboard.lastText !== "" && fakeClipboard.lastLabel.indexOf("address") !== -1,
          "clipboard route receives a bounded address and label")
        root.expect(!tailscaleService.toggleConnection()
          && tailscaleService.error === "Tailscale changes are disabled",
          "production-style mutation gate blocks connection writes")

        transport.allowMutations = true
        root.expect(tailscaleService.toggleConnection(), "gated down request is accepted")
        transport.fixtureResponses = ({ "tailscale.status": root.statusJson("Stopped", false) })
        root.stage = 1
        return
      }

      if (root.stage === 1) {
        if (tailscaleService.pendingAction !== "") return
        root.expect(!tailscaleService.connected, "down waits for stopped-state convergence")
        root.expect(commandRecorded("down", ["/usr/sbin/tailscale", "down"]),
          "down uses exact argv")
        root.expect(tailscaleService.toggleConnection(), "gated up request is accepted")
        transport.fixtureResponses = ({ "tailscale.status": root.statusJson("Running", false) })
        root.stage = 2
        return
      }

      if (root.stage === 2) {
        if (tailscaleService.pendingAction !== "") return
        root.expect(tailscaleService.connected, "up waits for running-state convergence")
        root.expect(commandRecorded("up", ["/usr/sbin/tailscale", "up"]),
          "up uses exact argv")
        root.expect(tailscaleService.setExitNode("peer-exit"),
          "gated exit-node request is accepted")
        transport.fixtureResponses = ({ "tailscale.status": root.statusJson("Running", true) })
        root.stage = 3
        return
      }

      if (root.stage === 3) {
        if (tailscaleService.pendingAction !== "") return
        root.expect(tailscaleService.currentExitNodeKey === "peer-exit",
          "exit-node selection waits for observed convergence")
        root.expect(commandRecorded("exit-set",
          ["/usr/sbin/tailscale", "set", "--exit-node=100.64.0.9"]),
          "exit-node selection uses the validated peer target")
        root.expect(tailscaleService.setExitNode("peer-exit"),
          "activating the selected exit node requests clear")
        transport.fixtureResponses = ({ "tailscale.status": root.statusJson("Running", false) })
        root.stage = 4
        return
      }

      if (root.stage === 4) {
        if (tailscaleService.pendingAction !== "") return
        sequence.stop()
        root.finish()
      }
    }
  }

  Timer {
    id: quitDelay
    interval: 250
    repeat: false
    onTriggered: Qt.quit()
  }

  Timer {
    interval: 15000
    running: true
    repeat: false
    onTriggered: {
      failures.push("fixture timed out at stage " + stage)
      writeResult()
      Qt.quit()
    }
  }
}
