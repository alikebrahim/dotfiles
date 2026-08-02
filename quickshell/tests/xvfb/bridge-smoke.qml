import QtQuick
import Quickshell
import services as Services

ShellRoot {
  id: root

  readonly property string resultPath: Quickshell.env("QUATTRO_QS_TEST_RESULT")
  readonly property string fixturePath: Quickshell.env("QUATTRO_AWESOME_STATE")
  property var failures: []
  property bool waitingForFileUpdate: false
  property bool waitingForFileRecovery: false
  property int revisionBeforeFileUpdate: 0

  Services.AwesomeBridge {
    id: bridge
    statePath: root.fixturePath
  }
  Services.CommandTransport {
    id: actionTransport
    fixtureMode: true
    allowMutations: true
  }
  Services.AwesomeActionService {
    id: awesomeActions
    bridge: bridge
    transport: actionTransport
  }

  function fail(message) {
    failures.push(String(message))
  }

  function expect(condition, message) {
    if (!condition) fail(message)
  }

  function shellQuote(value) {
    return "'" + String(value).replace(/'/g, "'\\''") + "'"
  }

  function writeResult() {
    var payload = JSON.stringify({
      ok: failures.length === 0,
      failures: failures,
      primaryOutput: bridge.primaryOutput,
      focusedTitle: bridge.focusedClient.title,
      tagCount: bridge.tags.length,
      revision: bridge.revision
    })
    Quickshell.execDetached([
      "bash",
      "-lc",
      "printf '%s' " + shellQuote(payload) + " > " + shellQuote(resultPath)
    ])
  }

  function requestFixtureUpdate() {
    var payload = JSON.stringify({
      primaryOutput: "screen-next",
      focusedOutput: "screen-next",
      outputs: [{ id: "screen-next", name: "DP-1" }],
      tags: [{ name: "3", selected: true, occupied: true, urgent: false }],
      focusedClient: { title: "Updated", class: "updated", screen: "screen-next" }
    })
    var temporaryPath = fixturePath + ".tmp"
    Quickshell.execDetached([
      "bash",
      "-lc",
      "printf '%s' " + shellQuote(payload) + " > " + shellQuote(temporaryPath)
        + " && mv " + shellQuote(temporaryPath) + " " + shellQuote(fixturePath)
    ])
  }

  function requestFixtureRecovery() {
    var payload = JSON.stringify({
      primaryOutput: "screen-recovered",
      focusedOutput: "screen-recovered",
      outputs: [{ id: "screen-recovered", name: "HDMI-A-1" }],
      tags: [{ name: "4", selected: true, occupied: false, urgent: false }],
      focusedClient: { title: "Recovered", class: "recovered", screen: "screen-recovered" }
    })
    var temporaryPath = fixturePath + ".recovery"
    Quickshell.execDetached([
      "bash",
      "-lc",
      "mv " + shellQuote(fixturePath) + " " + shellQuote(fixturePath + ".missing")
        + " && sleep 0.6 && printf '%s' " + shellQuote(payload) + " > " + shellQuote(temporaryPath)
        + " && mv " + shellQuote(temporaryPath) + " " + shellQuote(fixturePath)
    ])
  }

  Connections {
    target: bridge
    function onReadyChanged() {
      if (!bridge.ready) return

      root.expect(bridge.primaryOutput === "screen-primary", "fixture primary output is authoritative")
      root.expect(bridge.focusedOutput === "screen-secondary", "fixture focused output is exposed")
      root.expect(bridge.focusedClient.title === "Example window", "focused client title is exposed")
      root.expect(bridge.tags.length === 2, "tag list is exposed")
      root.expect(bridge.workspaceIndex === 1, "selected tag derives the authoritative workspace index")
      root.expect(bridge.workspaceSynchronized, "legacy fixture defaults to synchronized workspace state")
      root.expect(bridge.focusTag("1"), "published tag action is accepted")
      root.expect(!bridge.focusTag("missing"), "unknown tag action is rejected")
      root.expect(actionTransport.recordedActions.length === 1
        && actionTransport.recordedActions[0].key === "awesome.focus-tag"
        && actionTransport.recordedActions[0].command[0] === "awesome-client"
        && actionTransport.recordedActions[0].command[1].indexOf("require(\"signals\")") !== -1
        && actionTransport.recordedActions[0].command[1].indexOf("sync.view_index(index)") !== -1,
        "validated tag request reaches the shared Awesome workspace coordinator")
      root.expect(!awesomeActions.focusTag("1'; os.execute('bad')")
        && actionTransport.recordedActions.length === 1,
        "Awesome tag action rejects program-like tag input before dispatch")

      var revisionBeforeMalformed = bridge.revision
      root.expect(!bridge.applyRaw("{broken"), "malformed JSON is rejected")
      root.expect(bridge.revision === revisionBeforeMalformed, "malformed JSON preserves revision")
      root.expect(bridge.primaryOutput === "screen-primary", "malformed JSON preserves last known-good state")
      root.expect(!bridge.applyRaw(JSON.stringify({
        primaryOutput: "screen-primary",
        focusedOutput: "screen-primary",
        outputs: [],
        tags: [],
        focusedClient: {}
      })), "semantically incomplete bridge state is rejected")
      root.expect(bridge.revision === revisionBeforeMalformed && bridge.primaryOutput === "screen-primary",
        "invalid bridge topology preserves last-known-good state")
      root.expect(!bridge.applyRaw(JSON.stringify({
        primaryOutput: "screen-primary",
        focusedOutput: "screen-primary",
        outputs: [{ id: "screen-primary", name: "HDMI-0" }],
        tags: [{ name: "1" }, { name: "1" }],
        focusedClient: {}
      })), "duplicate bridge tags are rejected")
      root.expect(bridge.revision === revisionBeforeMalformed && bridge.tags.length === 2,
        "invalid tag topology preserves last-known-good tags")

      root.revisionBeforeFileUpdate = bridge.revision
      root.waitingForFileUpdate = true
      root.requestFixtureUpdate()
    }

    function onRevisionChanged() {
      if (bridge.revision <= root.revisionBeforeFileUpdate) return
      if (root.waitingForFileUpdate) {
        root.waitingForFileUpdate = false
        root.expect(bridge.primaryOutput === "screen-next", "valid update changes primary output")
        root.expect(bridge.focusedClient.title === "Updated", "valid update changes focused title")
        root.revisionBeforeFileUpdate = bridge.revision
        root.waitingForFileRecovery = true
        root.requestFixtureRecovery()
        return
      }
      if (!root.waitingForFileRecovery) return
      root.waitingForFileRecovery = false
      root.expect(bridge.primaryOutput === "screen-recovered", "bridge retries after the state file temporarily disappears")
      root.expect(bridge.focusedClient.title === "Recovered", "recovered bridge state is authoritative")

      root.writeResult()
      Qt.callLater(Qt.quit)
    }
  }

  Timer {
    interval: 3000
    running: true
    repeat: false
    onTriggered: {
      root.fail("bridge did not become ready")
      root.writeResult()
      Qt.callLater(Qt.quit)
    }
  }
}
