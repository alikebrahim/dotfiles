import QtQuick
import Quickshell
import services as Services
import modules.bar as Bar

ShellRoot {
  id: root

  readonly property string resultPath: Quickshell.env("QUICKSHELL_QS_TEST_RESULT")
  readonly property bool holdOpen: Quickshell.env("QUICKSHELL_MEDIA_TEST_HOLD") === "1"
  property var failures: []
  property int previousCalls: 0
  property int playCalls: 0
  property int pauseCalls: 0
  property int toggleCalls: 0
  property int nextCalls: 0

  QtObject {
    id: firstPlayer
    property string dbusName: "org.mpris.MediaPlayer2.alpha"
    property int uniqueId: 1
    property string identity: "Alpha Player"
    property string desktopEntry: "alpha"
    property string trackTitle: "A deliberately long track title that must be elided instead of scrolling across the bar"
    property string trackArtist: "Alpha Artist"
    property string trackAlbum: "First Album"
    property string trackArtUrl: ""
    property bool isPlaying: true
    property bool canControl: true
    property bool canTogglePlaying: true
    property bool canPlay: true
    property bool canPause: true
    property bool canGoPrevious: true
    property bool canGoNext: true
    function previous() { root.previousCalls += 1 }
    function play() { root.playCalls += 1; isPlaying = true }
    function pause() { root.pauseCalls += 1; isPlaying = false }
    function togglePlaying() { root.toggleCalls += 1; isPlaying = !isPlaying }
    function next() { root.nextCalls += 1 }
  }

  QtObject {
    id: secondPlayer
    property string dbusName: "org.mpris.MediaPlayer2.beta"
    property int uniqueId: 2
    property string identity: "Beta Player"
    property string desktopEntry: "beta"
    property string trackTitle: "Second Track"
    property string trackArtist: "Beta Artist"
    property string trackAlbum: "Second Album"
    property string trackArtUrl: "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='64' height='64'%3E%3Crect width='64' height='64' fill='%23d7c9bd'/%3E%3C/svg%3E"
    property bool isPlaying: false
    property bool canControl: true
    property bool canTogglePlaying: true
    property bool canPlay: true
    property bool canPause: true
    property bool canGoPrevious: true
    property bool canGoNext: true
    function previous() { root.previousCalls += 1 }
    function play() { root.playCalls += 1; isPlaying = true }
    function pause() { root.pauseCalls += 1; isPlaying = false }
    function togglePlaying() { root.toggleCalls += 1; isPlaying = !isPlaying }
    function next() { root.nextCalls += 1 }
  }

  QtObject {
    id: dormantPlayer
    property string dbusName: "org.mpris.MediaPlayer2.chromium.instance999"
    property int uniqueId: 3
    property string identity: "Chrome"
    property string desktopEntry: ""
    property string trackTitle: ""
    property string trackArtist: ""
    property string trackAlbum: ""
    property string trackArtUrl: ""
    property bool isPlaying: false
    property bool canControl: true
    property bool canTogglePlaying: false
    property bool canPlay: false
    property bool canPause: false
    property bool canGoPrevious: false
    property bool canGoNext: false
    function previous() { root.previousCalls += 100 }
    function play() { root.playCalls += 100 }
    function pause() { root.pauseCalls += 100 }
    function togglePlaying() { root.toggleCalls += 100 }
    function next() { root.nextCalls += 100 }
  }

  QtObject {
    id: backend
    property var players: [firstPlayer, secondPlayer, dormantPlayer]
  }

  Services.ShellState { id: shellState }
  Services.AwesomeBridge { id: bridge }
  Services.CommandTransport {
    id: transport
    fixtureMode: true
    allowMutations: false
  }
  Services.ModalController { id: modalController }
  Services.BarPopoutController {
    id: popoutController
    modalController: modalController
  }
  Services.MediaService {
    id: mediaService
    backend: backend
  }
  Services.AudioService {
    id: audio
    transport: transport
    backend: null
    useNativeBackend: false
  }
  Services.NetworkService { id: network; transport: transport; backend: null }
  Services.BluetoothService { id: bluetooth; transport: transport; backend: null }
  Services.PowerService { id: power; transport: transport; refreshOnStart: false }
  Services.BrightnessService { id: brightness; transport: transport; refreshOnStart: false }

  Bar.PrimaryBar {
    id: bar
    shellState: shellState
    bridge: bridge
    mediaService: mediaService
    audioService: audio
    networkService: network
    bluetoothService: bluetooth
    powerService: power
    brightnessService: brightness
    modalController: modalController
    barPopoutController: popoutController
  }

  function expect(condition, message) {
    if (!condition) failures.push(String(message))
  }

  function shellQuote(value) {
    return "'" + String(value).replace(/'/g, "'\\''") + "'"
  }

  function writeResult() {
    var payload = JSON.stringify({
      ok: failures.length === 0,
      failures: failures,
      sourceCount: mediaService.playerCount,
      activePlayerKey: mediaService.activePlayerKey,
      available: mediaService.available,
      widgetVisible: bar.mediaWidget.visible,
      popupOpen: bar.mediaWidget.popupOpen,
      activePopout: popoutController.activePopout,
      labelWidth: bar.mediaWidget.labelWidth,
      popupWidth: bar.mediaWidget.panel.width,
      popupHeight: bar.mediaWidget.panel.height,
      previousCalls: previousCalls,
      playCalls: playCalls,
      pauseCalls: pauseCalls,
      toggleCalls: toggleCalls,
      nextCalls: nextCalls
    })
    Quickshell.execDetached([
      "bash",
      "-lc",
      "printf '%s' " + shellQuote(payload) + " > " + shellQuote(resultPath)
    ])
  }

  function finishFixture() {
    root.expect(mediaService.playerCount === 1,
      "removing the preferred player falls back without retaining the dormant endpoint")
    root.expect(mediaService.activePlayerKey === mediaService.playerKey(firstPlayer),
      "the surviving actionable player becomes active")

    backend.players = [dormantPlayer]
    Qt.callLater(root.finishEmptyState)
  }

  function finishEmptyState() {
    root.expect(mediaService.playerCount === 0 && !mediaService.available,
      "a dormant endpoint does not keep media available")
    root.expect(!bar.mediaWidget.visible && !bar.mediaWidget.popupOpen,
      "the indicator and popup close when no actionable player remains")
    root.expect(popoutController.activePopout === "",
      "empty media releases bar-local popup ownership")

    if (!holdOpen) {
      root.writeResult()
      Qt.callLater(Qt.quit)
      return
    }

    backend.players = [firstPlayer, secondPlayer, dormantPlayer]
    mediaService.selectPlayer(mediaService.playerKey(secondPlayer))
    Qt.callLater(function() {
      bar.mediaWidget.openPopup()
      Qt.callLater(root.writeResult)
    })
  }

  Component.onCompleted: {
    var screenName = Quickshell.screens.length > 0 ? Quickshell.screens[0].name : ""
    bridge.applyRaw(JSON.stringify({
      primaryOutput: "fixture-primary",
      focusedOutput: "fixture-primary",
      outputs: [{ id: "fixture-primary", name: screenName }],
      tags: [{ name: "1", selected: true, occupied: true, urgent: false }],
      focusedClient: { title: "MPRIS fixture", class: "fixture", screen: "fixture-primary" }
    }))
  }

  Timer {
    interval: 140
    running: true
    repeat: false
    onTriggered: {
      root.expect(mediaService.backendReady, "fake MPRIS backend is ready")
      root.expect(mediaService.playerCount === 2,
        "only the two action-capable players are exposed")
      root.expect(mediaService.activePlayerKey === mediaService.playerKey(firstPlayer),
        "the playing source is selected first")
      root.expect(bar.mediaWidget.visible, "the media indicator is visible")
      root.expect(bar.mediaWidget.labelWidth <= 180,
        "the bar label is hard-bounded without a marquee")

      root.expect(mediaService.selectPlayer(mediaService.playerKey(secondPlayer)),
        "explicit player selection succeeds")
      firstPlayer.isPlaying = false
      root.expect(mediaService.activePlayerKey === mediaService.playerKey(secondPlayer),
        "explicit selection remains stable across playback-state changes")

      root.expect(bar.mediaWidget.openPopup(), "the media popup opens")
      root.expect(popoutController.activePopout === "media",
        "the media popup owns the bar-local controller")
      root.expect(bar.mediaWidget.panel.exclusiveZone === 0,
        "the media popup does not reserve workarea")

      root.expect(mediaService.runAction("previous", mediaService.activePlayerKey),
        "previous routes through the media service")
      root.expect(mediaService.runAction("playPause", mediaService.activePlayerKey),
        "play routes through the media service")
      root.expect(mediaService.runAction("playPause", mediaService.activePlayerKey),
        "pause routes through the media service")
      root.expect(mediaService.runAction("next", mediaService.activePlayerKey),
        "next routes through the media service")
      root.expect(previousCalls === 1 && playCalls === 1 && pauseCalls === 1
        && nextCalls === 1,
        "fake native actions are recorded exactly once")

      backend.players = [firstPlayer, dormantPlayer]
      Qt.callLater(root.finishFixture)
    }
  }

  Timer {
    interval: 60000
    running: true
    repeat: false
    onTriggered: Qt.quit()
  }
}
