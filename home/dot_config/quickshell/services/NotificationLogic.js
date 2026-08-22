.pragma library

function text(value, limit) {
  var result = value === undefined || value === null ? "" : String(value)
  result = result.replace(/\u0000/g, "")
  if (limit > 0 && result.length > limit) result = result.slice(0, limit)
  return result
}

function number(value, fallback) {
  var parsed = Number(value)
  return isFinite(parsed) ? parsed : fallback
}

function boolean(value) {
  return value === true
}

function actionList(notification) {
  var rows = []
  try {
    var actions = notification && notification.actions ? notification.actions : []
    for (var i = 0; i < actions.length; i++) {
      var action = actions[i]
      if (!action) continue
      rows.push({
        identifier: text(action.identifier, 120),
        text: text(action.text, 240)
      })
    }
  } catch (error) {
    return []
  }
  return rows
}

function hasDefaultAction(actions) {
  for (var i = 0; i < actions.length; i++) {
    if (actions[i].identifier === "default") return true
  }
  return false
}

function snapshot(notification, key, timestamp, revision, seen) {
  var actions = actionList(notification)
  return {
    key: text(key, 200),
    nativeId: number(notification ? notification.id : 0, 0),
    appName: text(notification ? notification.appName : "", 160),
    appIcon: text(notification ? notification.appIcon : "", 500),
    summary: text(notification ? notification.summary : "", 500),
    body: text(notification ? notification.body : "", 4000),
    image: text(notification ? notification.image : "", 2000),
    urgency: number(notification ? notification.urgency : 1, 1),
    isTransient: boolean(notification ? notification.transient : false),
    resident: boolean(notification ? notification.resident : false),
    expireTimeout: number(notification ? notification.expireTimeout : -1, -1),
    timestamp: number(timestamp, Date.now()),
    seen: boolean(seen),
    hasDefaultAction: hasDefaultAction(actions),
    revision: Math.max(1, Math.floor(number(revision, 1)))
  }
}

function storedSnapshot(value) {
  if (!value || typeof value !== "object") return null
  var key = text(value.key, 200)
  if (!key) return null
  return {
    key: key,
    nativeId: number(value.nativeId, 0),
    appName: text(value.appName, 160),
    appIcon: text(value.appIcon, 500),
    summary: text(value.summary, 500),
    body: text(value.body, 4000),
    image: text(value.image, 2000),
    urgency: number(value.urgency, 1),
    isTransient: false,
    resident: boolean(value.resident),
    expireTimeout: number(value.expireTimeout, -1),
    timestamp: number(value.timestamp, Date.now()),
    seen: boolean(value.seen),
    hasDefaultAction: false,
    revision: Math.max(1, Math.floor(number(value.revision, 1)))
  }
}

function copyRow(row) {
  return {
    key: text(row.key, 200),
    nativeId: number(row.nativeId, 0),
    appName: text(row.appName, 160),
    appIcon: text(row.appIcon, 500),
    summary: text(row.summary, 500),
    body: text(row.body, 4000),
    image: text(row.image, 2000),
    urgency: number(row.urgency, 1),
    isTransient: boolean(row.isTransient),
    resident: boolean(row.resident),
    expireTimeout: number(row.expireTimeout, -1),
    timestamp: number(row.timestamp, Date.now()),
    seen: boolean(row.seen),
    hasDefaultAction: boolean(row.hasDefaultAction),
    revision: Math.max(1, Math.floor(number(row.revision, 1)))
  }
}

function parseState(raw, historyCap) {
  var parsed
  try {
    parsed = JSON.parse(String(raw || ""))
  } catch (error) {
    return { ok: false, error: "invalid JSON: " + error }
  }

  if (!parsed || parsed.version !== 1 || !Array.isArray(parsed.history))
    return { ok: false, error: "unsupported notification state schema" }

  var history = []
  for (var i = 0; i < parsed.history.length && history.length < historyCap; i++) {
    var row = storedSnapshot(parsed.history[i])
    if (row) history.push(row)
  }

  return {
    ok: true,
    dnd: boolean(parsed.dnd),
    history: history
  }
}

function serializeState(dnd, rows) {
  return JSON.stringify({
    version: 1,
    dnd: boolean(dnd),
    history: rows
  })
}

function timeoutMs(snapshot, lowMs, normalMs, maxMs) {
  if (number(snapshot.urgency, 1) >= 2) return 0
  var requested = number(snapshot.expireTimeout, -1)
  var fallback = number(snapshot.urgency, 1) <= 0 ? lowMs : normalMs
  if (requested <= 0) return fallback
  return Math.max(1000, Math.min(requested, maxMs))
}
