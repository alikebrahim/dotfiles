import QtQuick
import Quickshell
import services as Services

ShellRoot {
  id: root

  readonly property string resultPath: Quickshell.env("QUATTRO_QS_TEST_RESULT")
  property var failures: []
  property bool sessionSuccessObserved: false
  property bool sessionFailureObserved: false
  property bool logoutSentinelObserved: false
  property bool clipboardFinished: false

  Services.CommandTransport {
    id: sessionTransport
    allowMutations: true
    timeoutMs: 500
    terminateGraceMs: 100
  }

  Services.SessionActionService {
    id: sessionActions
    transport: sessionTransport
    commandOverrides: ({
      suspend: ["/usr/bin/true"],
      restart: ["/usr/bin/false"],
      logout: ["/usr/bin/printf", "ACCEPTED"]
    })
  }

  Services.DbusOwnershipService {
    id: ownership
    probeEnabled: false
  }

  Services.X11ClipboardService {
    id: clipboard
    timeoutMs: 100
    terminateGraceMs: 100
    commandOverride: ["/usr/bin/sleep", "5"]
  }

  function expect(condition, message) {
    if (!condition) failures.push(message)
  }

  function shellQuote(value) {
    return "'" + String(value).replace(/'/g, "'\\''") + "'"
  }

  function writeResult() {
    var payload = JSON.stringify({
      ok: failures.length === 0 && sessionSuccessObserved
        && sessionFailureObserved && logoutSentinelObserved && clipboardFinished,
      failures: failures,
      sessionSuccessObserved: sessionSuccessObserved,
      sessionFailureObserved: sessionFailureObserved,
      logoutSentinelObserved: logoutSentinelObserved,
      clipboardFinished: clipboardFinished,
      clipboardError: clipboard.error
    })
    Quickshell.execDetached([
      "bash", "-lc",
      "printf '%s' " + shellQuote(payload) + " > " + shellQuote(resultPath)
    ])
  }

  function startSessionSequence() {
    expect(sessionActions.arm("suspend"), "suspend arms")
    expect(sessionActions.executeConfirmed("suspend"), "suspend dispatches")
    expect(sessionActions.busy, "session remains busy until completion")
  }

  Connections {
    target: sessionActions

    function onActionAccepted(action) {
      if (action === "suspend") {
        root.sessionSuccessObserved = true
        root.expect(!sessionActions.busy && sessionActions.error === "",
                    "successful session action clears busy/error")
        root.expect(sessionActions.arm("restart"), "restart arms")
        root.expect(sessionActions.executeConfirmed("restart"), "restart dispatches")
      } else if (action === "logout") {
        root.logoutSentinelObserved = true
        root.expect(sessionActions.error === "", "logout sentinel is accepted")
        root.expect(clipboard.copyText("fixture", "Fixture"), "clipboard timeout probe starts")
        clipboardPoll.start()
      }
    }

    function onActionFailed(action, message) {
      if (action !== "restart") return
      root.sessionFailureObserved = true
      root.expect(message.indexOf("exited with code") >= 0,
                  "session failure preserves bounded transport error")
      root.expect(sessionActions.armedAction === "restart",
                  "failed action remains confirmed for retry")
      sessionActions.cancelConfirmation()
      root.expect(sessionActions.arm("logout"), "logout arms")
      root.expect(sessionActions.executeConfirmed("logout"), "logout dispatches")
    }
  }

  Timer {
    id: clipboardPoll
    interval: 25
    repeat: true
    onTriggered: {
      if (clipboard.busy) return
      stop()
      root.clipboardFinished = true
      root.expect(clipboard.queuedText === "", "clipboard timeout clears queued text")
      root.expect(clipboard.error.indexOf("timed out") >= 0,
                  "clipboard timeout reports a visible error")
      root.writeResult()
      quitDelay.restart()
    }
  }

  Timer {
    id: quitDelay
    interval: 120
    repeat: false
    onTriggered: Qt.quit()
  }

  Component.onCompleted: {
    var owned = ownership.parseOwnerStatus("PID=42\n", "", 0, 42)
    var foreign = ownership.parseOwnerStatus("PID=7\n", "", 0, 42)
    var unowned = ownership.parseOwnerStatus("", "Failed to get credentials: No such device or address", 1, 42)
    var malformed = ownership.parseOwnerStatus("Id=fixture\n", "", 0, 42)
    expect(owned.state === "owned" && owned.pid === 42, "own PID is recognized")
    expect(foreign.state === "foreign" && foreign.pid === 7, "foreign PID is recognized")
    expect(unowned.state === "unowned" && unowned.pid === 0, "unowned bus name is recognized")
    expect(malformed.state === "unknown" && malformed.error !== "",
           "successful response without PID is unknown")
    startSessionSequence()
  }

  Timer {
    interval: 3000
    running: true
    repeat: false
    onTriggered: {
      root.failures.push("fixture timed out")
      root.writeResult()
      quitDelay.restart()
    }
  }
}
