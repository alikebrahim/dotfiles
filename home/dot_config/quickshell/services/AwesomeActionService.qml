import QtQuick

// Offline-testable adapter for the Awesome tag action boundary. The bridge
// validates that the requested tag exists; this adapter validates the token
// again and sends one static awesome-client program through the mutation gate.
Item {
  id: root

  required property QtObject bridge
  required property QtObject transport

  property string error: ""
  readonly property bool actionsEnabled: transport !== null && bridge !== null && bridge.ready

  signal windowActivationFinished(int windowId, bool ok, string message)

  visible: false

  function publishedTagIndex(name) {
    if (!actionsEnabled) return -1
    var requested = String(name || "")
    if (!/^[A-Za-z0-9][A-Za-z0-9_.:-]{0,63}$/.test(requested)) return -1
    for (var i = 0; i < bridge.tags.length; i++) {
      if (String(bridge.tags[i].name || "") === requested) return i + 1
    }
    return -1
  }

  function focusTag(name) {
    if (!actionsEnabled) {
      error = "Awesome bridge state is unavailable or stale"
      return false
    }
    var index = publishedTagIndex(name)
    if (index < 1) return false
    var program = "local index=" + index
      + "; local module=require(\"signals\"); local sync=module.workspace"
      + "; if sync and sync.view_index then local ok,err=sync.view_index(index)"
      + "; return ok and \"OK:focused\" or \"ERR:\"..tostring(err) end"
      + "; for s in screen do local t=s.tags[index]"
      + "; if t then t:view_only() end end; return \"OK:fallback\""
    transport.request("awesome.focus-tag", ["awesome-client", program], true)
    return true
  }

  function publishedWindowId(windowId) {
    if (!actionsEnabled) return 0
    var requested = Number(windowId)
    if (requested <= 0 || Math.floor(requested) !== requested) return 0
    for (var i = 0; i < bridge.clients.length; i++)
      if (Number(bridge.clients[i].id) === requested) return requested
    return 0
  }

  function activateWindow(windowId) {
    if (!actionsEnabled) {
      error = "Awesome bridge state is unavailable or stale"
      return false
    }
    var requested = publishedWindowId(windowId)
    if (requested === 0) {
      error = "Window is no longer available"
      return false
    }

    var program = "local awful=require(\"awful\"); local target_id=" + requested
      + "; local target=nil; for _,candidate in ipairs(client.get()) do"
      + " if candidate.valid and candidate.window==target_id then target=candidate; break end end"
      + "; if not target or not target.valid then return \"ERR:not-found\" end"
      + "; local target_tag=target.first_tag; if target_tag then local index=target_tag.index"
      + "; if index then local module=require(\"signals\"); local sync=module.workspace"
      + "; if sync and sync.view_index then sync.view_index(index,{restore_focus=false})"
      + "; else for s in screen do local t=s.tags[index]"
      + "; if t then t:view_only() end end end end end"
      + "; target.minimized=false; if target.screen then awful.screen.focus(target.screen) end"
      + "; target.urgent=false; client.focus=target; target:raise(); return \"OK:focused\""
    error = ""
    transport.request("awesome.activate-window." + requested, ["awesome-client", program], true)
    return true
  }

  Connections {
    target: root.bridge
    function onTagFocusRequested(name) { root.focusTag(name) }
  }

  Connections {
    target: root.transport
    function onFinished(requestId, key, ok, output, message) {
      if (key === "awesome.focus-tag") {
        root.error = ok ? "" : message
        return
      }
      var prefix = "awesome.activate-window."
      if (key.indexOf(prefix) !== 0) return
      var windowId = Number(key.substring(prefix.length))
      var succeeded = ok && String(output || "").indexOf("OK:focused") !== -1
      var detail = succeeded ? "" : String(output || message || "Window activation failed").trim()
      root.error = detail
      root.windowActivationFinished(windowId, succeeded, detail)
    }
  }
}
