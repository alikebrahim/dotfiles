import QtQuick
import Quickshell
import services as Services
import modules.bar as Bar
import modules.notifications as Notifications

ShellRoot {
  id: root

  readonly property string resultPath: Quickshell.env("QUICKSHELL_NOTIFICATION_TEST_RESULT")
  readonly property string mode: Quickshell.env("QUICKSHELL_NOTIFICATION_TEST_MODE") || "fake"
  property var failures: []
  property int stage: 0
  property int actionCalls: 0
  property int dismissCalls: 0
  property int expireCalls: 0
  readonly property var fixtureScreen: Quickshell.screens.length > 0
    ? Quickshell.screens[0]
    : null

  Services.NotificationService {
    id: notificationService
    lowToastMs: 350
    normalToastMs: 500
    maxToastMs: 1200
  }

  PanelWindow {
    id: fixtureBar
    screen: root.fixtureScreen
    visible: root.fixtureScreen !== null && notificationService.serverReady
    implicitWidth: 38
    implicitHeight: 32
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    focusable: false

    anchors {
      top: true
      right: true
    }

    Bar.NotificationWidget {
      anchors.centerIn: parent
      screen: root.fixtureScreen
      notificationService: notificationService
      barPopoutController: null
    }
  }

  Notifications.NotificationToasts {
    id: toasts
    notificationService: notificationService
    targetScreen: root.fixtureScreen
  }

  function expect(condition, message) {
    if (!condition) failures.push(String(message))
  }

  function shellQuote(value) {
    return "'" + String(value).replace(/'/g, "'\\''") + "'"
  }

  function writeResult(extra) {
    var payload = JSON.stringify({
      ok: failures.length === 0,
      failures: failures,
      mode: mode,
      serverReady: notificationService.serverReady,
      recoveredFromBackup: notificationService.recoveredFromBackup,
      historyCount: notificationService.historyCount,
      unseenCount: notificationService.unseenCount,
      popupCount: notificationService.popupCount,
      actionCalls: actionCalls,
      dismissCalls: dismissCalls,
      expireCalls: expireCalls,
      extra: extra || {}
    })
    Quickshell.execDetached([
      "bash",
      "-lc",
      "printf '%s' " + shellQuote(payload) + " > " + shellQuote(resultPath)
    ])
  }

  function fakeNotification(id, summary, urgency, isTransient, withDefault) {
    var notification = {
      id: id,
      tracked: false,
      lastGeneration: false,
      expireTimeout: -1,
      appName: "Fixture App",
      appIcon: "dialog-information",
      summary: summary,
      body: "Plain fixture body <b>must not become markup</b>",
      urgency: urgency,
      resident: false,
      desktopEntry: "fixture",
      image: "",
      actions: [],
      "transient": isTransient
    }
    if (withDefault) {
      notification.actions = [{
        identifier: "default",
        text: "Open",
        invoke: function() { root.actionCalls++ }
      }]
    }
    notification.dismiss = function() {
      root.dismissCalls++
      notificationService.handleNativeClosed(notificationService.nativeKey(notification), 1)
    }
    notification.expire = function() {
      root.expireCalls++
      notificationService.handleNativeClosed(notificationService.nativeKey(notification), 0)
    }
    return notification
  }

  function schedule(nextStage, delay) {
    stage = nextStage
    advanceTimer.interval = delay || 40
    advanceTimer.restart()
  }

  function runFakeStage() {
    if (stage === 0) {
      expect(notificationService.serverReady, "private notification server is instantiated")
      expect(notificationService.historyReady, "history state finished loading")
      expect(notificationService.recoveredFromBackup,
        "malformed primary state recovered from last-known-good backup")
      expect(notificationService.historyCount === 1,
        "backup history row was restored exactly once")
      notificationService.clearHistory()
      schedule(1)
      return
    }

    if (stage === 1) {
      var normal = fakeNotification(101, "Initial summary", 1, false, true)
      root.normalNotification = normal
      notificationService.acceptNotification(normal)
      schedule(2)
      return
    }

    if (stage === 2) {
      expect(notificationService.historyCount === 1,
        "normal notification enters bounded history")
      expect(notificationService.popupCount === 1,
        "normal notification enters the toast model")
      root.normalNotification.summary = "Replacement summary"
      notificationService.scheduleNativeRefresh(
        notificationService.nativeKey(root.normalNotification), true)
      schedule(3)
      return
    }

    if (stage === 3) {
      expect(notificationService.historyCount === 1 && notificationService.popupCount === 1,
        "replacement updates without duplicating history or toast rows")
      expect(notificationService.popupModel.get(0).summary === "Replacement summary",
        "replacement refreshes plain snapshot metadata")
      expect(notificationService.popupModel.get(0).revision === 2,
        "replacement increments the toast lifetime revision")
      expect(notificationService.invokeDefault(notificationService.nativeKey(root.normalNotification)),
        "default action invocation routes through the service")
      expect(actionCalls === 1, "fake default action ran exactly once")
      schedule(4)
      return
    }

    if (stage === 4) {
      expect(notificationService.popupCount === 0 && notificationService.seenRows.length === 1,
        "invoked toast moves to seen history")
      notificationService.setDoNotDisturb(true)
      var critical = fakeNotification(102, "DND critical", 2, false, false)
      var transientNotification = fakeNotification(103, "DND transient", 1, true, false)
      root.transientNotification = transientNotification
      notificationService.acceptNotification(critical)
      notificationService.acceptNotification(transientNotification)
      schedule(5)
      return
    }

    if (stage === 5) {
      expect(notificationService.popupCount === 0,
        "DND suppresses every toast including critical")
      expect(notificationService.historyCount === 2 && notificationService.unseenCount === 1,
        "DND collects non-transient critical history without duplicating seen rows")
      expect(notificationService.findRow(notificationService.historyModel,
        notificationService.nativeKey(root.transientNotification)) < 0,
        "DND transient notification is not persisted")
      expect(!notificationService.liveRefs[notificationService.nativeKey(root.transientNotification)],
        "suppressed transient native reference is released")
      notificationService.clearHistory()
      schedule(6)
      return
    }

    if (stage === 6) {
      notificationService.setDoNotDisturb(true)
      for (var i = 0; i < 105; i++)
        notificationService.acceptNotification(fakeNotification(2000 + i, "Cap " + i, 1, false, false))
      schedule(7, 160)
      return
    }

    if (stage === 7) {
      expect(notificationService.historyCount === 100,
        "one total history cap evicts entries beyond 100")
      notificationService.clearHistory()
      notificationService.setDoNotDisturb(false)
      schedule(8, 80)
      return
    }

    if (stage === 8) {
      var expiringToast = fakeNotification(9998, "Passive expiry", 1, false, false)
      root.expiringNotification = expiringToast
      notificationService.acceptNotification(expiringToast)
      schedule(9)
      return
    }

    if (stage === 9) {
      var expiringKey = notificationService.nativeKey(root.expiringNotification)
      expect(notificationService.popupCount === 1,
        "normal notification creates a visible toast before expiry")
      expect(notificationService.unseenCount === 1,
        "normal notification enters unseen history before expiry")
      expect(notificationService.expirePopup(expiringKey),
        "normal toast can expire through the service")
      schedule(10)
      return
    }

    if (stage === 10) {
      expect(notificationService.popupCount === 0,
        "expired toast leaves the popup model")
      expect(notificationService.unseenCount === 1 && notificationService.seenRows.length === 0,
        "passive expiry preserves unseen history")
      expect(expireCalls === 1, "passive expiry releases the fake native object")
      expect(notificationService.toastTimeout({ urgency: 1, expireTimeout: 0 }) === 0,
        "expire_timeout 0 never auto-expires")
      notificationService.clearHistory()
      schedule(11)
      return
    }

    if (stage === 11) {
      var criticalToast = fakeNotification(9999, "Persistent critical", 2, false, false)
      notificationService.acceptNotification(criticalToast)
      schedule(12)
      return
    }

    if (stage === 12) {
      expect(notificationService.popupCount === 1,
        "critical notification creates a visible toast")
      expect(notificationService.toastTimeout(notificationService.popupModel.get(0)) === 0,
        "critical toast has no automatic timeout")
      notificationService.dismissPopup(notificationService.popupModel.get(0).key)
      notificationService.clearHistory()
      schedule(13)
      return
    }

    expect(notificationService.popupCount === 0 && notificationService.historyCount === 0,
      "dismiss and clear leave no fixture notifications")
    writeResult({ finalStage: stage })
    Qt.callLater(Qt.quit)
  }

  property var normalNotification: null
  property var transientNotification: null
  property var expiringNotification: null

  Component.onCompleted: {
    if (mode === "fake") schedule(0, 250)
  }

  Timer {
    id: advanceTimer
    repeat: false
    onTriggered: root.runFakeStage()
  }

  Timer {
    interval: 60000
    running: true
    repeat: false
    onTriggered: {
      if (root.mode === "fake") {
        root.failures.push("fixture watchdog expired")
        root.writeResult({ watchdog: true })
      }
      Qt.quit()
    }
  }
}
