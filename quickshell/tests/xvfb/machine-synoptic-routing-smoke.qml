import QtQuick
import Quickshell

ShellRoot {
  id: root

  readonly property string resultPath: Quickshell.env("QUATTRO_QS_TEST_RESULT")
  property var failures: []

  Loader {
    id: controllerLoader
    source: "file://" + Quickshell.env("QUATTRO_MACHINE_SYNOPTIC")
    onLoaded: Qt.callLater(root.runChecks)
  }

  function expect(condition, message) {
    if (!condition) failures.push(String(message))
  }

  function roleFor(result, name) {
    for (var index = 0; index < result.roles.length; index++)
      if (result.roles[index].name === name) return result.roles[index].role
    return "missing"
  }

  function shellQuote(value) {
    return "'" + String(value).replace(/'/g, "'\\''") + "'"
  }

  function runChecks() {
    var controller = controllerLoader.item
    expect(controller !== null, "controller loads")
    if (!controller) {
      finish({})
      return
    }

    var outputs = [
      { id: "eDP-1-1", name: "eDP-1-1" },
      { id: "HDMI-0", name: "HDMI-0" }
    ]
    var dual = controller.resolveRoles(
      ["eDP-1-1", "HDMI-0"], true, false, "HDMI-0", outputs)
    expect(dual.primaryName === "HDMI-0", "Awesome primary resolves to HDMI-0")
    expect(roleFor(dual, "HDMI-0") === "primary", "HDMI-0 receives primary composition")
    expect(roleFor(dual, "eDP-1-1") === "auxiliary", "eDP-1-1 receives auxiliary composition")
    expect(!dual.degraded, "healthy bridge routing is nominal")

    var sole = controller.resolveRoles(
      ["eDP-1-1"], true, false, "eDP-1-1",
      [{ id: "eDP-1-1", name: "eDP-1-1" }])
    expect(sole.primaryName === "eDP-1-1", "sole eDP panel promotes to primary")
    expect(roleFor(sole, "eDP-1-1") === "primary", "promoted eDP receives full composition")
    expect(!sole.degraded, "healthy sole-output routing is nominal")

    var stale = controller.resolveRoles(
      ["eDP-1-1", "HDMI-0"], false, true, "HDMI-0", outputs)
    var stalePrimaryCount = 0
    for (var staleIndex = 0; staleIndex < stale.roles.length; staleIndex++)
      if (stale.roles[staleIndex].role === "primary") stalePrimaryCount++
    expect(stale.degraded, "stale bridge marks routing degraded")
    expect(stalePrimaryCount === 1, "stale multi-output fallback creates one primary")
    expect(stale.primaryName === "HDMI-0", "stale fallback is deterministic")

    var history = [{ sampledAtMs: 1 }, { sampledAtMs: 2 }]
    var sharedService = Qt.createQmlObject(
      'import QtQuick; QtObject { property var history300: [] }', root, "sharedTelemetry")
    sharedService.history300 = history
    controller.telemetryService = sharedService
    controller.resolveRoles(["eDP-1-1"], true, false, "eDP-1-1",
      [{ id: "eDP-1-1", name: "eDP-1-1" }])
    expect(controller.telemetryService.history300 === history,
      "role promotion preserves the shared history owner")

    finish({ dual: dual, sole: sole, stale: stale })
  }

  function finish(results) {
    var payload = JSON.stringify({
      ok: failures.length === 0,
      failures: failures,
      dual: results.dual || {},
      sole: results.sole || {},
      stale: results.stale || {}
    })
    Quickshell.execDetached([
      "bash", "-lc",
      "printf '%s' " + shellQuote(payload) + " > " + shellQuote(resultPath)
    ])
    quitDelay.start()
  }

  Timer {
    id: quitDelay
    interval: 150
    repeat: false
    onTriggered: Qt.quit()
  }

  Timer {
    interval: 5000
    running: true
    repeat: false
    onTriggered: {
      failures.push("fixture watchdog expired")
      root.finish({})
    }
  }
}
