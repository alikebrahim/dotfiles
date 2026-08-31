import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications as Native
import "NotificationLogic.js" as Logic

Item {
  id: root

  readonly property string stateRoot: Quickshell.env("XDG_STATE_HOME")
    || (Quickshell.env("HOME") ? Quickshell.env("HOME") + "/.local/state" : "")
  property string statePath: stateRoot
    ? stateRoot + "/quickshell-shell/notifications-v1.json"
    : ""
  property string backupPath: stateRoot
    ? stateRoot + "/quickshell-shell/notifications-v1.last-good.json"
    : ""
  property int historyCap: 100
  property int maxVisibleToasts: 4
  property int lowToastMs: 5000
  property int normalToastMs: 8000
  property int maxToastMs: 30000
  // Permanent authority after the verified Awesome-to-Quickshell cutover.
  readonly property bool configuredAuthority: true

  property bool historyReady: false
  property bool doNotDisturb: false
  property bool backupRequested: false
  property bool backupLoadComplete: false
  property bool backupAvailable: false
  property string backupRaw: ""
  property string mainFailureReason: ""
  property bool recoveredFromBackup: false
  property string lastError: ""
  property string pendingSavePayload: ""
  property string lastGoodPayload: ""
  property var liveRefs: ({})
  property var nativeKeys: ({})
  property var listeners: ({})
  property var refreshScheduled: ({})
  property var refreshReasons: ({})
  property var unseenRows: []
  property var seenRows: []
  property int liveActionRevision: 0

  readonly property alias historyModel: historyModel
  readonly property alias popupModel: popupModel
  readonly property int historyCount: historyModel.count
  readonly property int popupCount: popupModel.count
  readonly property int unseenCount: unseenRows.length
  readonly property bool serverReady: serverLoader.item !== null

  visible: false

  ListModel { id: historyModel }
  ListModel { id: popupModel }

  PersistentProperties {
    id: persisted
    reloadableId: "quickshell-native-notifications"
    property string serverSessionId: ""
    property string reloadStateJson: ""
  }

  FileView {
    id: stateFile
    path: root.statePath
    preload: root.statePath !== ""
    atomicWrites: true
    printErrors: false
    onLoaded: {
      if (!root.historyReady) root.loadMainState(text())
    }
    onLoadFailed: function(error) {
      if (!root.historyReady) root.requestBackup("primary state unavailable")
    }
    onSaveFailed: function(error) {
      root.lastError = "Notification state save failed: " + error
    }
  }

  FileView {
    id: backupFile
    path: root.backupPath
    preload: root.backupPath !== ""
    atomicWrites: true
    printErrors: false
    onLoaded: {
      root.backupLoadComplete = true
      root.backupAvailable = true
      root.backupRaw = text()
      if (!root.historyReady && root.backupRequested) root.resolveBackupRequest()
    }
    onLoadFailed: function(error) {
      root.backupLoadComplete = true
      root.backupAvailable = false
      if (!root.historyReady && root.backupRequested) root.resolveBackupRequest()
    }
    onSaveFailed: function(error) {
      root.lastError = "Notification backup save failed: " + error
    }
  }

  Timer {
    id: saveTimer
    interval: 250
    repeat: false
    onTriggered: root.flushState()
  }

  Loader {
    id: serverLoader
    active: root.configuredAuthority
    sourceComponent: Component {
      Native.NotificationServer {
        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        bodyMarkupSupported: false
        bodyHyperlinksSupported: false
        bodyImagesSupported: false
        actionsSupported: true
        actionIconsSupported: false
        imageSupported: true
        inlineReplySupported: false
        onNotification: function(notification) {
          root.acceptNotification(notification)
        }
      }
    }
  }

  function makeSessionId() {
    return Date.now().toString(36) + "-" + Math.floor(Math.random() * 0x7fffffff).toString(36)
  }

  function nativeKey(notification) {
    return persisted.serverSessionId + ":" + String(notification ? notification.id : 0)
  }

  function findRow(model, key) {
    for (var i = 0; i < model.count; i++) {
      var row = model.get(i)
      if (row && row.key === key) return i
    }
    return -1
  }

  function rowsFromHistory() {
    var rows = []
    for (var i = 0; i < historyModel.count; i++)
      rows.push(Logic.copyRow(historyModel.get(i)))
    return rows
  }

  function statePayload() {
    return Logic.serializeState(doNotDisturb, rowsFromHistory())
  }

  function rebuildHistoryViews() {
    var pending = []
    var past = []
    for (var i = 0; i < historyModel.count; i++) {
      var snapshot = Logic.copyRow(historyModel.get(i))
      if (snapshot.seen) past.push(snapshot)
      else pending.push(snapshot)
    }
    unseenRows = pending
    seenRows = past
  }

  function hydrateParsedState(parsed) {
    historyModel.clear()
    doNotDisturb = parsed.dnd
    for (var i = 0; i < parsed.history.length && i < historyCap; i++)
      historyModel.append(parsed.history[i])
    rebuildHistoryViews()
  }

  function loadMainState(raw) {
    var parsed = Logic.parseState(raw, historyCap)
    if (!parsed.ok) {
      requestBackup(parsed.error)
      return
    }
    hydrateParsedState(parsed)
    lastGoodPayload = Logic.serializeState(parsed.dnd, parsed.history)
    finishHistoryLoad()
  }

  function requestBackup(reason) {
    if (historyReady || backupRequested) return
    mainFailureReason = reason
    backupRequested = true
    if (backupLoadComplete) resolveBackupRequest()
  }

  function resolveBackupRequest() {
    if (historyReady || !backupRequested || !backupLoadComplete) return
    if (backupAvailable) {
      loadBackupState(backupRaw)
      return
    }
    if (mainFailureReason !== "primary state unavailable")
      lastError = "Notification state and backup are unavailable; using defaults"
    else
      lastError = ""
    finishHistoryLoad()
  }

  function loadBackupState(raw) {
    var parsed = Logic.parseState(raw, historyCap)
    if (!parsed.ok) {
      lastError = "Notification state and backup are unavailable; using defaults"
      finishHistoryLoad()
      return
    }
    hydrateParsedState(parsed)
    lastGoodPayload = Logic.serializeState(parsed.dnd, parsed.history)
    recoveredFromBackup = true
    lastError = "Notification state recovered from the last-known-good backup"
    finishHistoryLoad()
    scheduleStateSave()
  }

  function finishHistoryLoad() {
    if (historyReady) return
    historyReady = true
    rebuildHistoryViews()
    persisted.reloadStateJson = statePayload()
    var keys = Object.keys(liveRefs)
    for (var i = 0; i < keys.length; i++) scheduleNativeRefresh(keys[i], false)
  }

  function scheduleStateSave() {
    if (!historyReady) return
    pendingSavePayload = statePayload()
    persisted.reloadStateJson = pendingSavePayload
    saveTimer.restart()
  }

  function flushState() {
    var payload = pendingSavePayload || statePayload()
    pendingSavePayload = ""
    var parsed = Logic.parseState(payload, historyCap)
    if (!parsed.ok) {
      lastError = "Notification state save skipped: " + parsed.error
      return
    }
    if (backupPath && lastGoodPayload)
      backupFile.setText(lastGoodPayload)
    if (statePath) stateFile.setText(payload)
    lastGoodPayload = payload
  }

  function connectIfPresent(notification, signalName, handler) {
    try {
      var signal = notification[signalName]
      if (signal && typeof signal.connect === "function") signal.connect(handler)
    } catch (error) {}
  }

  function bindNotification(notification, key) {
    liveRefs[key] = notification
    nativeKeys[String(notification.id)] = key

    var refresh = function() { root.scheduleNativeRefresh(key, true) }
    var close = function(reason) { root.handleNativeClosed(key, reason) }
    listeners[key] = { refresh: refresh, close: close }

    connectIfPresent(notification, "expireTimeoutChanged", refresh)
    connectIfPresent(notification, "appNameChanged", refresh)
    connectIfPresent(notification, "appIconChanged", refresh)
    connectIfPresent(notification, "summaryChanged", refresh)
    connectIfPresent(notification, "bodyChanged", refresh)
    connectIfPresent(notification, "urgencyChanged", refresh)
    connectIfPresent(notification, "actionsChanged", refresh)
    connectIfPresent(notification, "residentChanged", refresh)
    connectIfPresent(notification, "transientChanged", refresh)
    connectIfPresent(notification, "desktopEntryChanged", refresh)
    connectIfPresent(notification, "imageChanged", refresh)
    connectIfPresent(notification, "closed", close)
    liveActionRevision++
  }

  function dropLiveReference(key) {
    var notification = liveRefs[key]
    var listener = listeners[key]
    if (notification && listener) {
      try { notification.expireTimeoutChanged.disconnect(listener.refresh) } catch (error) {}
      try { notification.appNameChanged.disconnect(listener.refresh) } catch (error) {}
      try { notification.appIconChanged.disconnect(listener.refresh) } catch (error) {}
      try { notification.summaryChanged.disconnect(listener.refresh) } catch (error) {}
      try { notification.bodyChanged.disconnect(listener.refresh) } catch (error) {}
      try { notification.urgencyChanged.disconnect(listener.refresh) } catch (error) {}
      try { notification.actionsChanged.disconnect(listener.refresh) } catch (error) {}
      try { notification.residentChanged.disconnect(listener.refresh) } catch (error) {}
      try { notification.transientChanged.disconnect(listener.refresh) } catch (error) {}
      try { notification.desktopEntryChanged.disconnect(listener.refresh) } catch (error) {}
      try { notification.imageChanged.disconnect(listener.refresh) } catch (error) {}
      try { notification.closed.disconnect(listener.close) } catch (error) {}
    }
    if (notification) delete nativeKeys[String(notification.id)]
    delete liveRefs[key]
    delete listeners[key]
    delete refreshScheduled[key]
    delete refreshReasons[key]
    liveActionRevision++
  }

  function acceptNotification(notification) {
    if (!notification) return
    notification.tracked = true
    var key = nativeKey(notification)
    if (liveRefs[key]) dropLiveReference(key)
    bindNotification(notification, key)
    scheduleNativeRefresh(key, false)
  }

  function scheduleNativeRefresh(key, replacement) {
    if (replacement) refreshReasons[key] = true
    else if (refreshReasons[key] === undefined) refreshReasons[key] = false
    if (!historyReady) return
    if (refreshScheduled[key]) return
    refreshScheduled[key] = true
    Qt.callLater(function() {
      var isReplacement = refreshReasons[key] === true
      delete refreshScheduled[key]
      delete refreshReasons[key]
      root.refreshNativeSnapshot(key, isReplacement)
    })
  }

  function refreshNativeSnapshot(key, replacement) {
    var notification = liveRefs[key]
    if (!notification) return

    var historyIndex = findRow(historyModel, key)
    var previous = historyIndex >= 0 ? Logic.copyRow(historyModel.get(historyIndex)) : null
    var preserveExisting = notification.lastGeneration && previous !== null && !replacement
    var timestamp = preserveExisting ? previous.timestamp : Date.now()
    var revision = previous ? previous.revision + (replacement ? 1 : 0) : 1
    var seen = preserveExisting ? previous.seen : false
    var snapshot = Logic.snapshot(notification, key, timestamp, revision, seen)

    if (snapshot.isTransient) {
      if (historyIndex >= 0) removeHistoryRowDirect(key, false)
    } else {
      upsertHistoryDirect(snapshot)
    }

    if (doNotDisturb) {
      removePopupDirect(key)
      if (snapshot.isTransient) releaseUntracked(key)
      return
    }

    if (notification.lastGeneration && previous && previous.seen && !replacement) {
      removePopupDirect(key)
      return
    }

    upsertPopupDirect(snapshot)
  }

  function upsertHistoryDirect(snapshot) {
    var index = findRow(historyModel, snapshot.key)
    if (index >= 0) {
      historyModel.set(index, snapshot)
      if (index > 0) historyModel.move(index, 0, 1)
    } else {
      historyModel.insert(0, snapshot)
    }

    while (historyModel.count > historyCap) {
      var evicted = Logic.copyRow(historyModel.get(historyModel.count - 1))
      historyModel.remove(historyModel.count - 1)
      releaseEvicted(evicted.key)
    }
    rebuildHistoryViews()
    scheduleStateSave()
  }

  function removeHistoryRowDirect(key, releaseLive) {
    var index = findRow(historyModel, key)
    if (index < 0) return false
    historyModel.remove(index)
    rebuildHistoryViews()
    scheduleStateSave()
    if (releaseLive) releaseDismissed(key)
    return true
  }

  function markHistorySeenDirect(key) {
    var index = findRow(historyModel, key)
    if (index < 0) return false
    if (!historyModel.get(index).seen) {
      historyModel.setProperty(index, "seen", true)
      rebuildHistoryViews()
      scheduleStateSave()
    }
    return true
  }

  function upsertPopupDirect(snapshot) {
    var index = findRow(popupModel, snapshot.key)
    if (index >= 0) {
      popupModel.set(index, snapshot)
      if (index > 0) popupModel.move(index, 0, 1)
    } else {
      popupModel.insert(0, snapshot)
    }

    while (popupModel.count > maxVisibleToasts) {
      var overflow = Logic.copyRow(popupModel.get(popupModel.count - 1))
      popupModel.remove(popupModel.count - 1)
      releaseExpired(overflow.key)
    }
  }

  function removePopupDirect(key) {
    var index = findRow(popupModel, key)
    if (index < 0) return false
    popupModel.remove(index)
    return true
  }

  function archivePopupDirect(key) {
    var removed = removePopupDirect(key)
    if (removed) markHistorySeenDirect(key)
    return removed
  }

  function handleNativeClosed(key, reason) {
    var wasVisible = removePopupDirect(key)
    if (wasVisible && reason !== Native.NotificationCloseReason.Expired)
      markHistorySeenDirect(key)
    dropLiveReference(key)
  }

  function liveDefaultAction(key) {
    liveActionRevision
    var notification = liveRefs[key]
    if (!notification) return null
    try {
      var actions = notification.actions || []
      for (var i = 0; i < actions.length; i++) {
        if (actions[i] && String(actions[i].identifier) === "default") return actions[i]
      }
    } catch (error) {
      return null
    }
    return null
  }

  function canInvokeDefault(key) {
    return liveDefaultAction(key) !== null
  }

  function invokeDefault(key) {
    var action = liveDefaultAction(key)
    if (!action) return false
    try {
      action.invoke()
      archivePopupDirect(key)
      markHistorySeenDirect(key)
      return true
    } catch (error) {
      lastError = "Notification action failed: " + error
      return false
    }
  }

  function releaseUntracked(key) {
    var notification = liveRefs[key]
    if (!notification) return
    dropLiveReference(key)
    try { notification.tracked = false } catch (error) {}
  }

  function releaseExpired(key) {
    var notification = liveRefs[key]
    if (!notification) return
    try { notification.expire() } catch (error) { dropLiveReference(key) }
  }

  function releaseDismissed(key) {
    var notification = liveRefs[key]
    if (!notification) return
    try { notification.dismiss() } catch (error) { dropLiveReference(key) }
  }

  function releaseEvicted(key) {
    removePopupDirect(key)
    releaseDismissed(key)
  }

  function expirePopup(key) {
    if (!removePopupDirect(key)) return false
    releaseExpired(key)
    return true
  }

  function dismissPopup(key) {
    if (!removePopupDirect(key)) return false
    markHistorySeenDirect(key)
    releaseDismissed(key)
    return true
  }

  function removeHistoryKey(key) {
    Qt.callLater(function() {
      root.removePopupDirect(key)
      root.removeHistoryRowDirect(key, true)
    })
    return true
  }

  function markSeenKey(key) {
    Qt.callLater(function() {
      root.removePopupDirect(key)
      if (root.markHistorySeenDirect(key)) root.releaseDismissed(key)
    })
    return true
  }

  function markAllSeen() {
    Qt.callLater(function() {
      var keys = []
      for (var i = 0; i < historyModel.count; i++) {
        var row = historyModel.get(i)
        if (!row.seen) {
          historyModel.setProperty(i, "seen", true)
          keys.push(row.key)
        }
      }
      for (var j = 0; j < keys.length; j++) {
        root.removePopupDirect(keys[j])
        root.releaseDismissed(keys[j])
      }
      root.rebuildHistoryViews()
      root.scheduleStateSave()
    })
    return true
  }

  function clearHistory() {
    Qt.callLater(function() {
      var keys = []
      for (var i = 0; i < historyModel.count; i++) keys.push(historyModel.get(i).key)
      historyModel.clear()
      root.rebuildHistoryViews()
      root.scheduleStateSave()
      for (var j = 0; j < keys.length; j++) {
        root.removePopupDirect(keys[j])
        root.releaseDismissed(keys[j])
      }
    })
    return true
  }

  function suppressVisibleToasts() {
    var transientKeys = []
    for (var i = popupModel.count - 1; i >= 0; i--) {
      var row = popupModel.get(i)
      if (row.isTransient) transientKeys.push(row.key)
      popupModel.remove(i)
    }
    for (var j = 0; j < transientKeys.length; j++) releaseUntracked(transientKeys[j])
  }

  function setDoNotDisturb(value) {
    var next = Boolean(value)
    if (doNotDisturb === next) return false
    doNotDisturb = next
    if (doNotDisturb) suppressVisibleToasts()
    scheduleStateSave()
    return true
  }

  function toggleDoNotDisturb() {
    setDoNotDisturb(!doNotDisturb)
    return doNotDisturb
  }

  function toastTimeout(snapshot) {
    return Logic.timeoutMs(snapshot, lowToastMs, normalToastMs, maxToastMs)
  }

  Component.onCompleted: {
    if (!persisted.serverSessionId) persisted.serverSessionId = makeSessionId()

    if (persisted.reloadStateJson) {
      var parsed = Logic.parseState(persisted.reloadStateJson, historyCap)
      if (parsed.ok) {
        hydrateParsedState(parsed)
        lastGoodPayload = Logic.serializeState(parsed.dnd, parsed.history)
        finishHistoryLoad()
      }
    }
  }
}
