import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../ui" as Ui
import "../../style" as ShellStyle

Item {
  id: root

  property var screen: null
  property var audio: null
  property var network: null
  property var bluetooth: null
  property var power: null
  property var brightness: null
  property var modalController: null
  property var barPopoutController: null
  property var popoutHost: null
  property string activeControl: "audio"
  readonly property string surfaceName: "controls"
  readonly property var popoutController: barPopoutController || modalController

  readonly property int statusCount: 5
  readonly property alias audioText: audioStatus.text
  readonly property alias networkText: networkStatus.text
  readonly property alias bluetoothText: bluetoothStatus.text
  readonly property alias powerText: powerStatus.text
  readonly property alias brightnessText: brightnessStatus.text
  readonly property alias microphoneIndicatorVisible: microphoneStatus.visible
  readonly property alias panel: controlPanel
  readonly property alias keyboardNavigator: keyboardNavigator
  readonly property alias panelTitle: panelContent.panelTitle

  implicitWidth: statusRow.implicitWidth
  implicitHeight: ShellStyle.Metrics.barHeight

  function focusKeyboardItem() {
    if (controlPanel.open && !panelContent.editorActive)
      keyboardNavigator.forceActiveFocus(Qt.ShortcutFocusReason)
  }

  function requestKeyboardFocus() {
    if (!controlPanel.open) return
    var windowObject = popoutHost && popoutHost.contentItem
      ? popoutHost.contentItem.Window.window
      : null
    if (!windowObject) return
    if (windowObject.active) focusKeyboardItem()
    else windowObject.requestActivate()
  }

  function syncAudioDetailLifecycle() {
    if (audio && typeof audio.setDetailOpen === "function")
      audio.setDetailOpen(controlPanel.open && activeControl === "audio")
  }

  function syncNetworkDetailLifecycle() {
    if (network && typeof network.setDetailOpen === "function")
      network.setDetailOpen(controlPanel.open && activeControl === "network")
  }

  function syncBluetoothDetailLifecycle() {
    if (bluetooth && typeof bluetooth.setDetailOpen === "function")
      bluetooth.setDetailOpen(controlPanel.open && activeControl === "bluetooth")
  }

  function openControl(name) {
    var allowed = ["audio", "network", "bluetooth", "power", "brightness"]
    var requested = String(name || "")
    if (allowed.indexOf(requested) === -1) return false
    if (controlPanel.open && activeControl === requested) {
      closePanel()
      return true
    }
    if (popoutController) popoutController.activate(surfaceName)
    activeControl = requested
    controlPanel.open = true
    return true
  }
  function showControl(name) {
    var allowed = ["audio", "network", "bluetooth", "power", "brightness"]
    var requested = String(name || "")
    if (allowed.indexOf(requested) === -1) return false
    if (popoutController) popoutController.activate(surfaceName)
    activeControl = requested
    controlPanel.open = true
    return true
  }
  function openPanel() {
    if (popoutController) popoutController.activate(surfaceName)
    controlPanel.open = true
  }
  function closePanel() {
    controlPanel.open = false
    if (popoutController) popoutController.release(surfaceName)
  }
  function togglePanel() { controlPanel.open ? closePanel() : openPanel() }
  function cycleControl(direction) {
    var controls = ["bluetooth", "network", "audio", "brightness", "power"]
    var index = controls.indexOf(activeControl)
    if (index < 0) index = 0
    activeControl = controls[(index + (direction < 0 ? -1 : 1) + controls.length) % controls.length]
    controlPanel.open = true
  }

  onActiveControlChanged: {
    syncAudioDetailLifecycle()
    syncNetworkDetailLifecycle()
    syncBluetoothDetailLifecycle()
  }

  RowLayout {
    id: statusRow
    anchors.fill: parent
    spacing: ShellStyle.Metrics.controlGap

    BluetoothStatus {
      id: bluetoothStatus
      service: root.bluetooth
      barPopoutController: root.barPopoutController
      onActivated: root.openControl("bluetooth")
    }
    NetworkStatus {
      id: networkStatus
      service: root.network
      barPopoutController: root.barPopoutController
      onActivated: root.openControl("network")
    }
    AudioStatus {
      id: audioStatus
      service: root.audio
      barPopoutController: root.barPopoutController
      onActivated: root.openControl("audio")
    }
    StatusText {
      id: microphoneStatus
      visible: root.audio !== null && root.audio.microphoneInUse
      barPopoutController: root.barPopoutController
      text: String.fromCodePoint(0xF036C)
      tooltipText: root.audio && root.audio.microphoneInUse
        ? "Microphone in use" + (root.audio.captureStreamCount > 1 ? " · " + root.audio.captureStreamCount + " sources" : "")
        : "Microphone idle"
      available: root.audio !== null && root.audio.inputAvailable
      onActivated: root.openControl("audio")
      onMiddleActivated: if (root.audio && root.audio.actionsEnabled) root.audio.toggleInputMute()
    }
    BrightnessStatus {
      id: brightnessStatus
      service: root.brightness
      barPopoutController: root.barPopoutController
      onActivated: root.openControl("brightness")
    }
    PowerStatus {
      id: powerStatus
      service: root.power
      barPopoutController: root.barPopoutController
      onActivated: root.openControl("power")
    }
  }

  readonly property Item popupAnchor: activeControl === "bluetooth" ? bluetoothStatus
    : (activeControl === "network" ? networkStatus
      : (activeControl === "brightness" ? brightnessStatus
        : (activeControl === "power" ? powerStatus : audioStatus)))

  Ui.PopupCard {
    id: controlPanel
    host: root.popoutHost
    anchorItem: root.popupAnchor
    placement: "anchor"
    animateTransitions: !root.popoutController
      || (!root.popoutController.dismissImmediately
        && !root.popoutController.switching)
    cardWidth: ShellStyle.Metrics.popupWidth
    cardHeight: panelContent.implicitHeight + padding * 2
    cardRadius: ShellStyle.Metrics.cornerRadius
    cardColor: ShellStyle.Palette.panel
    borderColor: ShellStyle.Palette.panelBorder

    onOpenChanged: {
      root.syncAudioDetailLifecycle()
      root.syncNetworkDetailLifecycle()
      root.syncBluetoothDetailLifecycle()
      if (open) {
        if (root.popoutController) root.popoutController.activate(root.surfaceName)
        panelContent.refreshActive()
      } else if (root.popoutController) {
        root.popoutController.release(root.surfaceName)
      }
    }

    Ui.KeyboardNavigator {
      id: keyboardNavigator
      anchors.fill: parent
      blocked: panelContent.editorActive
      onCloseRequested: root.closePanel()
      onMoveRequested: function(dx, dy) {
        panelContent.moveCursor(dx, dy)
      }
      onActivateRequested: panelContent.activateCursor()
      onTabRequested: function(direction) { root.cycleControl(direction) }
      onTextKey: function(text) { panelContent.handleTextKey(text) }
    }

    ControlContent {
      id: panelContent
      anchors.fill: parent
      activeControl: root.activeControl
      audio: root.audio
      network: root.network
      bluetooth: root.bluetooth
      power: root.power
      brightness: root.brightness
      onKeyboardFocusRequested: Qt.callLater(root.focusKeyboardItem)
    }
  }

  Connections {
    target: root.popoutHost
    enabled: root.popoutHost !== null
    function onFocusRequested() {
      if (controlPanel.open) root.focusKeyboardItem()
    }
  }

  Connections {
    target: root.popoutController
    function onCloseRequested(surface) {
      if (surface === root.surfaceName) root.closePanel()
    }
  }

  IpcHandler {
    target: "controls"

    function show(name: string): string {
      return root.showControl(name) ? root.activeControl : "invalid"
    }

    function close(): string {
      root.closePanel()
      return "closed"
    }

    function openAudio(): string { root.showControl("audio"); return "audio" }
    function openNetwork(): string { root.showControl("network"); return "network" }
    function openBluetooth(): string { root.showControl("bluetooth"); return "bluetooth" }
    function openPower(): string { root.showControl("power"); return "power" }
    function openBrightness(): string { root.showControl("brightness"); return "brightness" }
    function openDisplay(): string { return openBrightness() }

    function status(): string {
      return JSON.stringify({
        open: controlPanel.open,
        activeControl: root.activeControl,
        audioDetailOpen: root.audio ? root.audio.detailOpen : false,
        networkDetailOpen: root.network ? root.network.detailOpen : false,
        networkCount: root.network ? root.network.networks.length : 0,
        bluetoothDetailOpen: root.bluetooth ? root.bluetooth.detailOpen : false,
        bluetoothDiscovering: root.bluetooth ? root.bluetooth.discovering : false,
        bluetoothCount: root.bluetooth ? root.bluetooth.devices.length : 0,
        bluetoothPending: root.bluetooth ? root.bluetooth.pending : false,
        microphoneInUse: root.audio ? root.audio.microphoneInUse : false
      })
    }
  }

  Component.onDestruction: {
    if (root.audio && typeof root.audio.setDetailOpen === "function") root.audio.setDetailOpen(false)
    if (root.network && typeof root.network.setDetailOpen === "function") root.network.setDetailOpen(false)
    if (root.bluetooth && typeof root.bluetooth.setDetailOpen === "function") root.bluetooth.setDetailOpen(false)
  }
}
