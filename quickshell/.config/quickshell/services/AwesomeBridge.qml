import QtQuick
import Quickshell.Io

Item {
  id: root

  property string statePath: ""
  property bool stateValid: false
  property bool heartbeatObserved: false
  property bool ready: false
  property bool stale: false
  property double publishedAtMs: 0
  property double bridgeAgeMs: -1
  property string producerGeneration: ""
  property int staleAfterMs: 6000
  property int revision: 0
  property string lastError: ""
  property string primaryOutput: ""
  property string focusedOutput: ""
  property int workspaceIndex: 0
  property bool workspaceSynchronized: true
  property var outputs: []
  property var tags: []
  property var clients: []
  property var keybinds: []
  property var focusedClient: ({ title: "", class: "", screen: "" })

  signal tagFocusRequested(string name)

  function updateHealth() {
    if (!stateValid) {
      bridgeAgeMs = -1
      stale = false
      ready = false
      return
    }
    if (!heartbeatObserved || publishedAtMs <= 0) {
      bridgeAgeMs = -1
      stale = false
      ready = true
      return
    }

    bridgeAgeMs = Math.floor(Math.max(0, Date.now() - publishedAtMs))
    stale = bridgeAgeMs > staleAfterMs
    ready = !stale
    var staleMessage = "Awesome bridge heartbeat is stale"
    if (stale && !lastError) lastError = staleMessage
    else if (!stale && lastError === staleMessage) lastError = ""
  }

  function focusTag(name) {
    if (!ready) return false
    var requested = String(name || "")
    if (!requested) return false
    for (var i = 0; i < tags.length; i++) {
      if (String(tags[i].name || "") === requested) {
        tagFocusRequested(requested)
        return true
      }
    }
    return false
  }

  function normalizedTag(value) {
    var tag = value && typeof value === "object" ? value : {}
    return {
      name: String(tag.name || ""),
      selected: !!tag.selected,
      occupied: !!tag.occupied,
      urgent: !!tag.urgent
    }
  }

  function normalizedOutput(value) {
    var output = value && typeof value === "object" ? value : {}
    return {
      id: String(output.id || ""),
      name: String(output.name || ""),
      x: Number(output.x || 0),
      side: /^[LRC]$/.test(String(output.side || "")) ? String(output.side) : "C"
    }
  }

  function normalizedClient(value) {
    var candidate = value && typeof value === "object" ? value : {}
    return {
      id: Number(candidate.id || 0),
      title: String(candidate.title || ""),
      class: String(candidate.class || ""),
      output: String(candidate.output || ""),
      side: /^[LRC]$/.test(String(candidate.side || "")) ? String(candidate.side) : "C",
      tagIndex: Number(candidate.tagIndex || 0),
      minimized: !!candidate.minimized,
      maximized: !!candidate.maximized,
      fullscreen: !!candidate.fullscreen,
      urgent: !!candidate.urgent,
      focused: !!candidate.focused
    }
  }

  function normalizedKeybind(value) {
    var candidate = value && typeof value === "object" ? value : {}
    return {
      combo: String(candidate.combo || "").slice(0, 80),
      description: String(candidate.description || "").slice(0, 240),
      group: String(candidate.group || "misc").toLowerCase().slice(0, 64)
    }
  }

  function normalize(raw) {
    if (!raw || typeof raw !== "object" || Array.isArray(raw))
      throw new Error("bridge state must be an object")

    var primary = String(raw.primaryOutput || "")
    if (!primary) throw new Error("bridge state is missing primaryOutput")

    var nextPublishedAtMs = Number(raw.publishedAtMs || 0)
    if (nextPublishedAtMs < 0
        || Math.floor(nextPublishedAtMs) !== nextPublishedAtMs)
      throw new Error("bridge heartbeat timestamp is invalid")
    var nextGeneration = String(raw.producerGeneration || "").slice(0, 160)
    if (nextPublishedAtMs > 0 && !nextGeneration)
      throw new Error("bridge heartbeat is missing producerGeneration")

    var nextOutputs = Array.isArray(raw.outputs) ? raw.outputs.map(normalizedOutput) : []
    if (nextOutputs.length === 0)
      throw new Error("bridge state is missing outputs")
    var primaryFound = false
    var focused = String(raw.focusedOutput || primary)
    var focusedFound = false
    var outputIds = {}
    for (var i = 0; i < nextOutputs.length; i++) {
      if (!nextOutputs[i].id || !nextOutputs[i].name)
        throw new Error("bridge output is missing id or name")
      if (outputIds[nextOutputs[i].id])
        throw new Error("bridge output ids must be unique")
      outputIds[nextOutputs[i].id] = true
      if (nextOutputs[i].id === primary) primaryFound = true
      if (nextOutputs[i].id === focused) focusedFound = true
    }
    if (!primaryFound)
      throw new Error("primaryOutput is not present in outputs")
    if (!focusedFound)
      throw new Error("focusedOutput is not present in outputs")

    var client = raw.focusedClient && typeof raw.focusedClient === "object"
      ? raw.focusedClient
      : {}
    var nextTags = Array.isArray(raw.tags) ? raw.tags.map(normalizedTag) : []
    var tagNames = {}
    var derivedWorkspaceIndex = 0
    for (var tagIndex = 0; tagIndex < nextTags.length; tagIndex++) {
      var tagName = nextTags[tagIndex].name
      if (!/^[A-Za-z0-9][A-Za-z0-9_.:-]{0,63}$/.test(tagName))
        throw new Error("bridge tag name is not actionable")
      if (tagNames[tagName])
        throw new Error("bridge tag names must be unique")
      tagNames[tagName] = true
      if (nextTags[tagIndex].selected) {
        if (derivedWorkspaceIndex !== 0)
          throw new Error("bridge state must select one logical workspace")
        derivedWorkspaceIndex = tagIndex + 1
      }
    }
    var nextWorkspaceIndex = raw.workspaceIndex === undefined
      ? derivedWorkspaceIndex : Number(raw.workspaceIndex)
    if (nextTags.length > 0
        && (nextWorkspaceIndex < 1 || nextWorkspaceIndex > nextTags.length
            || Math.floor(nextWorkspaceIndex) !== nextWorkspaceIndex))
      throw new Error("bridge workspace index is unavailable")
    if (derivedWorkspaceIndex !== 0 && nextWorkspaceIndex !== derivedWorkspaceIndex)
      throw new Error("bridge workspace index does not match selected tag")

    var nextClients = Array.isArray(raw.clients) ? raw.clients.map(normalizedClient) : []
    var clientIds = {}
    for (var clientIndex = 0; clientIndex < nextClients.length; clientIndex++) {
      var nextClient = nextClients[clientIndex]
      if (nextClient.id <= 0 || Math.floor(nextClient.id) !== nextClient.id)
        throw new Error("bridge client id must be a positive integer")
      if (clientIds[nextClient.id])
        throw new Error("bridge client ids must be unique")
      if (!outputIds[nextClient.output])
        throw new Error("bridge client output is not present in outputs")
      if (nextClient.tagIndex < 0 || Math.floor(nextClient.tagIndex) !== nextClient.tagIndex)
        throw new Error("bridge client tag index must be a non-negative integer")
      clientIds[nextClient.id] = true
    }

    var nextKeybinds = []
    if (Array.isArray(raw.keybinds)) {
      for (var keybindIndex = 0; keybindIndex < raw.keybinds.length && keybindIndex < 128; keybindIndex++) {
        var keybind = normalizedKeybind(raw.keybinds[keybindIndex])
        if (keybind.combo && keybind.description) nextKeybinds.push(keybind)
      }
    }

    return {
      publishedAtMs: nextPublishedAtMs,
      producerGeneration: nextGeneration,
      primaryOutput: primary,
      focusedOutput: focused,
      workspaceIndex: nextWorkspaceIndex,
      workspaceSynchronized: raw.workspaceSynchronized !== false,
      outputs: nextOutputs,
      tags: nextTags,
      clients: nextClients,
      keybinds: nextKeybinds,
      focusedClient: {
        title: String(client.title || ""),
        class: String(client.class || ""),
        screen: String(client.screen || "")
      }
    }
  }

  function applyRaw(text) {
    try {
      var next = normalize(JSON.parse(String(text || "")))
      if (next.publishedAtMs > 0) {
        publishedAtMs = next.publishedAtMs
        producerGeneration = next.producerGeneration
        heartbeatObserved = true
      }
      primaryOutput = next.primaryOutput
      focusedOutput = next.focusedOutput
      workspaceIndex = next.workspaceIndex
      workspaceSynchronized = next.workspaceSynchronized
      outputs = next.outputs
      tags = next.tags
      clients = next.clients
      keybinds = next.keybinds
      focusedClient = next.focusedClient
      lastError = ""
      revision++
      stateValid = true
      updateHealth()
      retryTimer.stop()
      return true
    } catch (error) {
      lastError = String(error)
      console.warn("awesome bridge state rejected:", lastError)
      return false
    }
  }

  FileView {
    id: stateFile
    path: root.statePath
    watchChanges: true
    printErrors: false
    onLoaded: root.applyRaw(text())
    onLoadFailed: retryTimer.restart()
    onFileChanged: reload()
  }

  Timer {
    id: retryTimer
    interval: 1000
    repeat: false
    onTriggered: if (root.statePath) stateFile.reload()
  }

  Timer {
    interval: 1000
    repeat: true
    running: root.stateValid
    onTriggered: root.updateHealth()
  }

  onStatePathChanged: {
    stateValid = false
    heartbeatObserved = false
    publishedAtMs = 0
    producerGeneration = ""
    updateHealth()
    retryTimer.restart()
    stateFile.reload()
  }

  Component.onCompleted: if (statePath) stateFile.reload()
}
