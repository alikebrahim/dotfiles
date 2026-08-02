import QtQuick
import Quickshell.Services.Mpris as NativeMpris

Item {
  id: root

  property var backend: NativeMpris.Mpris
  property string preferredPlayerKey: ""
  property string lastError: ""

  readonly property bool backendReady: backend !== null && backend !== undefined
  readonly property var players: {
    if (!backend || !backend.players) return []
    var model = backend.players
    if (Array.isArray(model)) return model.slice()
    var values = model.values
    return values ? [...values] : []
  }
  readonly property var sourcePlayers: orderedSourcePlayers()
  readonly property int playerCount: sourcePlayers.length
  readonly property var activePlayer: selectActivePlayer()
  readonly property string activePlayerKey: playerKey(activePlayer)
  readonly property bool available: activePlayer !== null
  readonly property bool playing: activePlayer ? Boolean(activePlayer.isPlaying) : false
  readonly property string title: activePlayer ? String(activePlayer.trackTitle || "") : ""
  readonly property string artist: activePlayer ? String(activePlayer.trackArtist || "") : ""
  readonly property string album: activePlayer ? String(activePlayer.trackAlbum || "") : ""
  readonly property string artUrl: activePlayer ? String(activePlayer.trackArtUrl || "") : ""
  readonly property string identity: activePlayer ? appLabel(activePlayer) : ""
  readonly property string barLabel: {
    if (!activePlayer) return ""
    var primary = title || identity || "Media"
    return artist ? primary + "  ·  " + artist : primary
  }

  visible: false

  function playerKey(player) {
    if (!player) return ""
    var dbusName = String(player.dbusName || "").trim()
    if (dbusName) return dbusName
    if (player.uniqueId !== undefined && player.uniqueId !== null)
      return "unique:" + String(player.uniqueId)
    var fallback = String(player.desktopEntry || player.identity || "").trim()
    return fallback ? "identity:" + fallback : ""
  }

  function appLabel(player) {
    if (!player) return ""
    var label = String(player.identity || player.desktopEntry || "").trim()
    if (label) return label
    var dbusName = String(player.dbusName || "")
      .replace(/^org\.mpris\.MediaPlayer2\./, "")
      .replace(/\.instance[0-9]+$/, "")
    return dbusName || "Media"
  }

  function playerLabel(player) {
    if (!player) return ""
    return String(player.trackTitle || appLabel(player) || "Media")
  }

  function playerDetail(player) {
    if (!player) return ""
    return String(player.trackArtist || appLabel(player) || "")
  }

  function isActionable(player) {
    return Boolean(player && (
      player.canTogglePlaying
      || player.canPlay
      || player.canPause
      || player.canGoPrevious
      || player.canGoNext
    ))
  }

  function orderedSourcePlayers() {
    var list = []
    for (var i = 0; i < players.length; i++) {
      var player = players[i]
      if (isActionable(player) && playerKey(player)) list.push(player)
    }
    list.sort(function(a, b) {
      if (Boolean(a.isPlaying) !== Boolean(b.isPlaying)) return a.isPlaying ? -1 : 1
      var labelOrder = playerLabel(a).localeCompare(playerLabel(b))
      return labelOrder !== 0 ? labelOrder : playerKey(a).localeCompare(playerKey(b))
    })
    return list
  }

  function playerForKey(key) {
    var requested = String(key || "")
    if (!requested) return null
    for (var i = 0; i < sourcePlayers.length; i++) {
      if (playerKey(sourcePlayers[i]) === requested) return sourcePlayers[i]
    }
    return null
  }

  function selectActivePlayer() {
    var preferred = playerForKey(preferredPlayerKey)
    return preferred || (sourcePlayers.length > 0 ? sourcePlayers[0] : null)
  }

  function syncPreferredPlayer() {
    if (preferredPlayerKey && !playerForKey(preferredPlayerKey)) preferredPlayerKey = ""
  }

  function selectPlayer(key) {
    var player = playerForKey(key)
    if (!player) return false
    preferredPlayerKey = playerKey(player)
    return true
  }

  function actionAvailable(action, key) {
    var player = playerForKey(key) || activePlayer
    if (!player) return false
    if (action === "previous") return Boolean(player.canGoPrevious)
    if (action === "next") return Boolean(player.canGoNext)
    if (action === "playPause") {
      if (player.isPlaying) return Boolean(player.canPause || player.canTogglePlaying)
      return Boolean(player.canPlay || player.canTogglePlaying)
    }
    return false
  }

  function runAction(action, key) {
    var player = playerForKey(key) || activePlayer
    if (!player || !actionAvailable(action, playerKey(player))) return false

    try {
      if (action === "previous") {
        player.previous()
      } else if (action === "next") {
        player.next()
      } else if (action === "playPause") {
        if (player.isPlaying && player.canPause) player.pause()
        else if (!player.isPlaying && player.canPlay) player.play()
        else player.togglePlaying()
      } else {
        return false
      }
    } catch (error) {
      lastError = String(error || "Media action failed")
      errorClear.restart()
      return false
    }

    preferredPlayerKey = playerKey(player)
    lastError = ""
    errorClear.stop()
    return true
  }

  onSourcePlayersChanged: syncPreferredPlayer()

  Timer {
    id: errorClear
    interval: 10000
    repeat: false
    onTriggered: root.lastError = ""
  }
}
