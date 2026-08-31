import QtQuick
import Quickshell
import Quickshell.Networking
import services as Services
import modules.controls as Controls

ShellRoot {
  id: root

  readonly property string resultPath: Quickshell.env("QUATTRO_QS_TEST_RESULT")
  readonly property bool externalKeys: Quickshell.env("QUATTRO_EXTERNAL_KEYS") === "1"
  property var failures: []
  property var networkCheckpoints: []

  Services.CommandTransport {
    id: transport
    fixtureMode: true
    allowMutations: true
    fixtureResponses: ({
      "network.general": "enabled\nconnected\nfull\n",
      "network.active": "Home Wifi:802-11-wireless:wlp4s0\n",
      "network.signal": "*:78:Home Wifi\n",
      "power.upower": "Device: /org/freedesktop/UPower/devices/battery_BAT0\n  power supply: yes\n  present: yes\n  state: discharging\n  percentage: 73%\n  on-battery: yes\n",
      "power.active": "Current active profile: balanced\n",
      "power.profiles": "- balanced\n- performance\n- powersave\n",
      "brightness.state": "intel_backlight,backlight,48000,40%,120000\n"
    })
  }

  QtObject {
    id: outputAudio
    property real volume: 0.65
    property bool muted: false
    signal volumesChanged()
    onVolumeChanged: volumesChanged()
  }
  QtObject {
    id: inputAudio
    property real volume: 0.55
    property bool muted: false
    signal volumesChanged()
    onVolumeChanged: volumesChanged()
  }
  QtObject {
    id: streamAudio
    property real volume: 0.80
    property bool muted: false
    signal volumesChanged()
    onVolumeChanged: volumesChanged()
  }
  QtObject {
    id: captureAudio
    property real volume: 1.0
    property bool muted: false
    signal volumesChanged()
    onVolumeChanged: volumesChanged()
  }
  QtObject {
    id: outputNode
    property int id: 41
    property string name: "alsa_output.pci-main.analog-stereo"
    property string description: "Built-in Speakers"
    property string nickname: "Speakers"
    property bool isSink: true
    property bool isStream: false
    property bool ready: true
    property var properties: ({})
    property QtObject audio: outputAudio
  }
  QtObject {
    id: inputNode
    property int id: 61
    property string name: "alsa_input.pci-main.analog-stereo"
    property string description: "Built-in Microphone"
    property string nickname: "Microphone"
    property bool isSink: false
    property bool isStream: false
    property bool ready: true
    property var properties: ({})
    property QtObject audio: inputAudio
  }
  QtObject {
    id: streamNode
    property int id: 71
    property string name: "music-player"
    property string description: "Music Player"
    property string nickname: ""
    property bool isSink: true
    property bool isStream: true
    property bool ready: true
    property var properties: ({ "application.name": "Music Player" })
    property QtObject audio: streamAudio
  }
  QtObject {
    id: captureNode
    property int id: 72
    property string name: "meeting-recorder"
    property string description: "Meeting Recorder"
    property string nickname: ""
    property bool isSink: false
    property bool isStream: true
    property bool ready: true
    property var properties: ({ "application.name": "Meeting Recorder" })
    property QtObject audio: captureAudio
  }
  QtObject {
    id: audioBackend
    property bool ready: true
    property var nodes: [outputNode, inputNode, streamNode, captureNode]
    property var defaultAudioSink: outputNode
    property var defaultAudioSource: inputNode
    property var preferredDefaultAudioSink: outputNode
    property var preferredDefaultAudioSource: inputNode
    onPreferredDefaultAudioSinkChanged: defaultAudioSink = preferredDefaultAudioSink
    onPreferredDefaultAudioSourceChanged: defaultAudioSource = preferredDefaultAudioSource
  }

  QtObject {
    id: homeNetwork
    property string name: "Home Wifi"
    property bool connected: true
    property bool known: true
    property int state: ConnectionState.Connected
    property bool stateChanging: false
    property real signalStrength: 0.78
    property int security: WifiSecurityType.Wpa2Psk
    signal connectionFailed(int reason)
    function connect() { connected = true; known = true; state = ConnectionState.Connected }
    function connectWithPsk(psk) { connect() }
    function disconnect() { connected = false; state = ConnectionState.Disconnected }
    function forget() { known = false }
  }
  QtObject {
    id: protectedNetwork
    property string name: "Workshop"
    property bool connected: false
    property bool known: false
    property int state: ConnectionState.Disconnected
    property bool stateChanging: false
    property real signalStrength: 0.91
    property int security: WifiSecurityType.Wpa2Psk
    signal connectionFailed(int reason)
    function connect() { connected = true; known = true; state = ConnectionState.Connected }
    function connectWithPsk(psk) { connect() }
    function disconnect() { connected = false; state = ConnectionState.Disconnected }
    function forget() { known = false }
  }
  QtObject {
    id: wifiNetworks
    property var values: [homeNetwork, protectedNetwork]
  }
  QtObject {
    id: wifiDevice
    property int type: DeviceType.Wifi
    property string name: "wlp4s0"
    property bool connected: homeNetwork.connected || protectedNetwork.connected
    property int state: connected ? ConnectionState.Connected : ConnectionState.Disconnected
    property bool scannerEnabled: false
    property QtObject networks: wifiNetworks
  }
  QtObject {
    id: networkDevices
    property var values: [wifiDevice]
  }
  QtObject {
    id: networkBackend
    property bool ready: true
    property bool wifiEnabled: true
    property bool wifiHardwareEnabled: true
    property int connectivity: NetworkConnectivity.Full
    property QtObject devices: networkDevices
  }

  QtObject {
    id: connectedHeadphones
    property string address: "11:22:33:44:55:66"
    property string deviceName: "Headphones"
    property string name: "Headphones"
    property string icon: "audio-headset"
    property bool connected: true
    property bool paired: true
    property bool bonded: true
    property bool pairing: false
    property bool trusted: true
    property bool batteryAvailable: true
    property real battery: 0.8
    property int disconnectCalls: 0
    function connect() { connected = true }
    function disconnect() { disconnectCalls++; connected = false }
    function pair() { paired = true; bonded = true }
    function forget() { connected = false; paired = false; bonded = false; trusted = false }
  }
  QtObject {
    id: knownKeyboard
    property string address: "22:33:44:55:66:77"
    property string deviceName: "Keyboard"
    property string name: "Keyboard"
    property string icon: "input-keyboard"
    property bool connected: false
    property bool paired: true
    property bool bonded: true
    property bool pairing: false
    property bool trusted: true
    property bool batteryAvailable: false
    property real battery: 0
    function connect() { connected = true }
    function disconnect() { connected = false }
    function pair() { paired = true; bonded = true }
    function forget() { connected = false; paired = false; bonded = false; trusted = false }
  }
  QtObject {
    id: bluetoothDevices
    property var values: [connectedHeadphones, knownKeyboard]
  }
  QtObject {
    id: bluetoothAdapter
    property string adapterId: "hci0"
    property string name: "Fixture adapter"
    property bool enabled: true
    property bool discovering: false
  }
  QtObject {
    id: bluetoothBackend
    property QtObject defaultAdapter: bluetoothAdapter
    property QtObject devices: bluetoothDevices
  }

  Services.AudioService {
    id: audio
    transport: transport
    backend: audioBackend
    useNativeBackend: false
  }
  Services.NetworkService { id: network; transport: transport; backend: networkBackend }
  Services.BluetoothService { id: bluetooth; transport: transport; backend: bluetoothBackend }
  Services.PowerService { id: power; transport: transport; refreshOnStart: false }
  Services.BrightnessService { id: brightness; transport: transport; refreshOnStart: false }

  Controls.SystemControls {
    id: controls
    screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    audio: audio
    network: network
    bluetooth: bluetooth
    power: power
    brightness: brightness
  }

  function expect(condition, message) {
    if (!condition) failures.push(String(message))
  }

  function shellQuote(value) {
    return "'" + String(value).replace(/'/g, "'\\''") + "'"
  }

  function validateNetworkPanel() {
    root.networkCheckpoints = root.networkCheckpoints.concat([{
      stage: "after-settle",
      detailOpen: network.detailOpen,
      scanning: wifiDevice.scannerEnabled,
      count: network.networks.length,
      wifi: network.wifiEnabled,
      pending: network.pending,
      error: network.error
    }])
    root.expect(network.detailOpen && wifiDevice.scannerEnabled && network.networks.length === 2,
      "Network panel attaches native rows and scanning only while open")
    controls.keyboardNavigator.dispatchKey(Qt.Key_Down, "", Qt.NoModifier)
    controls.keyboardNavigator.dispatchKey(Qt.Key_Down, "", Qt.NoModifier)
    controls.keyboardNavigator.dispatchKey(Qt.Key_Down, "", Qt.NoModifier)
    controls.keyboardNavigator.dispatchKey(Qt.Key_Return, "", Qt.NoModifier)
    root.networkCheckpoints = root.networkCheckpoints.concat([{
      stage: "after-enter",
      selectedId: network.credentialNetworkId,
      credentialOpen: network.credentialOpen,
      blocked: controls.keyboardNavigator.blocked,
      pending: network.pending,
      error: network.error
    }])
    root.expect(network.credentialOpen && controls.keyboardNavigator.blocked,
      "keyboard activation opens a focused inline PSK lifecycle without launching a helper")
    network.cancelCredentials()
    controls.keyboardNavigator.dispatchKey(Qt.Key_W, "w", Qt.NoModifier)
    root.networkCheckpoints = root.networkCheckpoints.concat([{
      stage: "after-toggle",
      wifi: network.wifiEnabled,
      pending: network.pending,
      actions: transport.recordedActions.length,
      error: network.error
    }])
    root.expect(transport.recordedActions.length === 2 && !network.wifiEnabled && !network.pending,
      "Network mnemonic toggles native NetworkManager state without a command action")

    controls.keyboardNavigator.dispatchKey(Qt.Key_Backtab, "", Qt.ShiftModifier)
    root.expect(controls.activeControl === "bluetooth", "Shift+Tab switches to the previous control")
    root.expect(!network.detailOpen && !wifiDevice.scannerEnabled && network.networks.length === 0,
      "leaving Network detaches scanning and transient row snapshots")
    controls.keyboardNavigator.dispatchKey(Qt.Key_Escape, "", Qt.NoModifier)
    Qt.callLater(function() {
      root.expect(!controls.panel.open && !controls.panel.focusable,
        "Escape logically closes the panel and releases keyboard focus before fade-out")
      controls.openControl("power")
      Qt.callLater(function() {
        root.expect(controls.panelTitle === "Power" && controls.activeControl === "power",
          "power widget opens the Power panel hero")
        root.finish()
      })
    })
  }

  function finish() {
    var payload = JSON.stringify({
      ok: failures.length === 0,
      failures: failures,
      statusCount: controls.statusCount,
      audioText: controls.audioText,
      networkText: controls.networkText,
      bluetoothText: controls.bluetoothText,
      powerText: controls.powerText,
      brightnessText: controls.brightnessText,
      panelVisible: controls.panel.visible,
      panelExclusiveZone: controls.panel.exclusiveZone,
      panelFocusable: controls.panel.focusable,
      panelWidth: controls.panel.cardWidth,
      panelHeight: controls.panel.cardHeight,
      panelTitle: controls.panelTitle || "",
      activeControl: controls.activeControl || "",
      networkCheckpoints: networkCheckpoints
    })
    Quickshell.execDetached(["bash", "-lc", "printf '%s' " + shellQuote(payload) + " > " + shellQuote(resultPath)])
    Qt.callLater(Qt.quit)
  }

  Component.onCompleted: {
    audio.refresh()
    network.refresh()
    bluetooth.refresh()
    power.refresh()
    brightness.refresh()
    controls.openControl("audio")
  }

  Timer {
    // Wait beyond both the 75ms native-detail settle and 80ms X11 activation request.
    interval: 200
    running: true
    repeat: false
    onTriggered: {
      root.expect(controls.statusCount === 5, "all five status components exist")
      root.expect(controls.microphoneIndicatorVisible, "microphone privacy indicator appears only for an active capture stream")
      root.expect(controls.audioText !== "" && controls.audioText.indexOf("VOL") === -1, "audio uses an icon slot instead of a text badge")
      root.expect(controls.networkText !== "" && controls.networkText.indexOf("NET") === -1, "network uses an icon slot instead of a text badge")
      root.expect(controls.bluetoothText !== "" && controls.bluetoothText.indexOf("BT") === -1, "Bluetooth uses an icon slot instead of a text badge")
      root.expect(controls.powerText !== "" && controls.powerText.indexOf("BAT") === -1, "power uses an icon slot instead of a text badge")
      root.expect(controls.brightnessText !== "" && controls.brightnessText.indexOf("BRI") === -1, "brightness uses an icon slot instead of a text badge")
      var hasControlRouting = typeof controls.openControl === "function"
      root.expect(hasControlRouting, "bar widgets route to their matching control panel")
      root.expect(controls.panel.visible && controls.panel.exclusiveZone === 0 && controls.panel.focusable, "control panel is focusable and reserves no workarea")
      root.expect(controls.keyboardNavigator.activeFocus, "control panel transfers keyboard focus to its navigator")
      root.expect(controls.panel.cardWidth === 380, "control panel keeps the 380px content width")
      root.expect(controls.panel.cardHeight > 340 && controls.panel.cardHeight <= 600,
        "complete audio panel is height-capped and scrollable")
      root.expect(controls.panelTitle === "Audio" && controls.activeControl === "audio", "audio widget opens the Audio panel hero")
      root.expect(audio.detailOpen, "opening Audio attaches native detail snapshots")
      root.expect(controls.showControl("audio") && controls.showControl("audio") && controls.panel.open,
        "IPC-style show routing is idempotent when the requested panel is already open")
      if (root.externalKeys) {
        externalKeyTimeout.restart()
        externalKeyPoll.start()
        return
      }
      controls.keyboardNavigator.dispatchKey(Qt.Key_Right, "", Qt.NoModifier)
      root.expect(transport.recordedActions.length === 0 && Math.abs(outputAudio.volume - 0.70) < 0.001,
        "first movement key adjusts the focused audio control")
      controls.keyboardNavigator.dispatchKey(Qt.Key_Right, "", Qt.NoModifier)
      Qt.callLater(function() {
          root.expect(transport.recordedActions.length === 0 && Math.abs(outputAudio.volume - 0.75) < 0.001,
            "keyboard navigation adjusts native PipeWire audio without a command action")

          controls.keyboardNavigator.dispatchKey(Qt.Key_Tab, "", Qt.NoModifier)
          root.expect(controls.activeControl === "brightness", "Tab switches to the next control in bar order")
          controls.keyboardNavigator.dispatchKey(Qt.Key_Right, "", Qt.NoModifier)
          controls.keyboardNavigator.dispatchKey(Qt.Key_Right, "", Qt.NoModifier)
          root.expect(transport.recordedActions.length === 1
            && transport.recordedActions[0].command.join(" ") === "brightnessctl set 50%",
            "brightness panel is keyboard adjustable")

          controls.keyboardNavigator.dispatchKey(Qt.Key_Tab, "", Qt.NoModifier)
          root.expect(controls.activeControl === "power", "Tab reaches the Power panel")
          controls.keyboardNavigator.dispatchKey(Qt.Key_Right, "", Qt.NoModifier)
          controls.keyboardNavigator.dispatchKey(Qt.Key_Right, "", Qt.NoModifier)
          controls.keyboardNavigator.dispatchKey(Qt.Key_Return, "", Qt.NoModifier)
          root.expect(transport.recordedActions.length === 2
            && transport.recordedActions[1].command.join(" ") === "tuned-adm profile performance",
            "power-profile row is keyboard traversable and activatable")

          controls.keyboardNavigator.dispatchKey(Qt.Key_Tab, "", Qt.NoModifier)
          root.expect(controls.activeControl === "bluetooth", "Tab wraps to Bluetooth")
          bluetoothStageTimer.restart()
      })
    }
  }

  Timer {
    id: bluetoothStageTimer
    // Wait beyond the service's 75ms coalesced native-detail refresh.
    interval: 100
    repeat: false
    onTriggered: {
      root.expect(bluetooth.detailOpen && bluetooth.discovering && bluetooth.devices.length === 2,
        "Bluetooth panel attaches bounded native discovery and device rows only while open")
      controls.keyboardNavigator.dispatchKey(Qt.Key_Down, "", Qt.NoModifier)
      controls.keyboardNavigator.dispatchKey(Qt.Key_Down, "", Qt.NoModifier)
      controls.keyboardNavigator.dispatchKey(Qt.Key_Down, "", Qt.NoModifier)
      controls.keyboardNavigator.dispatchKey(Qt.Key_Return, "", Qt.NoModifier)
      root.expect(connectedHeadphones.disconnectCalls === 1 && !connectedHeadphones.connected
        && !bluetooth.pending && transport.recordedActions.length === 2,
        "keyboard device-row activation converges through native BlueZ without a command action")
      controls.keyboardNavigator.dispatchKey(Qt.Key_B, "b", Qt.NoModifier)
      root.expect(!bluetooth.powered && !bluetooth.discovering && !bluetooth.pending
        && transport.recordedActions.length === 2,
        "Bluetooth mnemonic toggles the native adapter and stops owned discovery")
      controls.keyboardNavigator.dispatchKey(Qt.Key_Tab, "", Qt.NoModifier)
      root.expect(controls.activeControl === "network", "Tab reaches Network")
      root.expect(!bluetooth.detailOpen && bluetooth.devices.length === 0,
        "leaving Bluetooth clears its transient device snapshots")
      networkStageTimer.restart()
    }
  }

  Timer {
    id: networkStageTimer
    // Wait beyond the service's 75ms coalesced native-detail refresh.
    interval: 100
    repeat: false
    onTriggered: root.validateNetworkPanel()
  }

  Timer {
    id: externalKeyPoll
    interval: 50
    repeat: true
    onTriggered: {
      if (transport.recordedActions.length < 2 || outputAudio.volume < 0.70 || controls.panel.open) return
      stop()
      externalKeyTimeout.stop()
      var expected = [
        "brightnessctl set 50%",
        "tuned-adm profile performance"
      ]
      root.expect(controls.activeControl === "network", "real Tab events traversed all control panels")
      root.expect(!network.wifiEnabled && !network.pending,
        "real X11 Network mnemonic converged through the injected native backend")
      root.expect(transport.recordedActions.length === expected.length, "real X11 keys produced exactly two command-backed fixture mutations")
      for (var i = 0; i < expected.length && i < transport.recordedActions.length; i++)
        root.expect(transport.recordedActions[i].command.join(" ") === expected[i], "real X11 key action " + i + " matches the keyboard contract")
      root.finish()
    }
  }

  Timer {
    id: externalKeyTimeout
    // Background terminal startup may spend several seconds initializing the
    // shell before Quickshell maps on an otherwise idle Xvfb display.
    interval: 30000
    repeat: false
    onTriggered: {
      externalKeyPoll.stop()
      root.expect(false, "timed out waiting for real X11 keyboard events")
      root.finish()
    }
  }
}
