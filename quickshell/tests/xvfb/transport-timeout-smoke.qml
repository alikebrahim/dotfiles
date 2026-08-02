import QtQuick
import Quickshell
import services as Services

ShellRoot {
  id: root

  readonly property string resultPath: Quickshell.env("QUATTRO_QS_TEST_RESULT")
  property bool timeoutFinished: false
  property bool timeoutSucceeded: true
  property string timeoutError: ""
  property bool queuedFinished: false
  property bool queuedSucceeded: false
  property string queuedOutput: ""
  property bool revokedFinished: false
  property bool revokedSucceeded: true
  property string revokedError: ""
  property bool duplicateCoalesced: false
  property bool failedFinished: false
  property string failedError: ""
  property bool overflowFinished: false
  property string overflowError: ""

  Services.CommandTransport {
    id: transport
    fixtureMode: false
    timeoutMs: 150
    terminateGraceMs: 150
    maxQueued: 3

    onFinished: function(requestId, key, success, output, error) {
      if (key === "timeout.probe") {
        root.timeoutFinished = true
        root.timeoutSucceeded = success
        root.timeoutError = error
      } else if (key === "timeout.revoked") {
        root.revokedFinished = true
        root.revokedSucceeded = success
        root.revokedError = error
      } else if (key === "timeout.failed") {
        root.failedFinished = true
        root.failedError = error
      } else if (key === "timeout.overflow") {
        root.overflowFinished = true
        root.overflowError = error
      } else if (key === "timeout.queued") {
        root.queuedFinished = true
        root.queuedSucceeded = success
        root.queuedOutput = output
        root.writeResult()
        Qt.callLater(Qt.quit)
      }
    }
  }

  function shellQuote(value) {
    return "'" + String(value).replace(/'/g, "'\\''") + "'"
  }

  function writeResult() {
    var payload = JSON.stringify({
      ok: timeoutFinished && !timeoutSucceeded
        && timeoutError.indexOf("timed out") !== -1
        && duplicateCoalesced
        && revokedFinished && !revokedSucceeded
        && revokedError === "mutations disabled"
        && failedFinished && failedError.indexOf("exited with code") !== -1
        && overflowFinished && overflowError === "command queue full"
        && queuedFinished && queuedSucceeded
        && queuedOutput === "queue-recovered",
      timeoutFinished: timeoutFinished,
      timeoutSucceeded: timeoutSucceeded,
      timeoutError: timeoutError,
      queuedFinished: queuedFinished,
      queuedSucceeded: queuedSucceeded,
      queuedOutput: queuedOutput,
      duplicateCoalesced: duplicateCoalesced,
      revokedFinished: revokedFinished,
      revokedSucceeded: revokedSucceeded,
      revokedError: revokedError,
      failedFinished: failedFinished,
      failedError: failedError,
      overflowFinished: overflowFinished,
      overflowError: overflowError
    })
    Quickshell.execDetached(["bash", "-lc", "printf '%s' " + shellQuote(payload) + " > " + shellQuote(resultPath)])
  }

  Component.onCompleted: {
    var firstRequest = transport.request("timeout.probe", ["sleep", "5"], false)
    var duplicateRequest = transport.request("timeout.probe", ["sleep", "5"], false)
    duplicateCoalesced = firstRequest === duplicateRequest
    transport.request("timeout.failed", ["false"], false)
    transport.request("timeout.queued", ["printf", "queue-recovered"], false)
    transport.allowMutations = true
    transport.request("timeout.revoked", ["printf", "must-not-run"], true)
    transport.allowMutations = false
    transport.request("timeout.overflow", ["printf", "must-not-run"], false)
  }

  Timer {
    interval: 2000
    running: true
    repeat: false
    onTriggered: {
      root.writeResult()
      Qt.callLater(Qt.quit)
    }
  }
}
