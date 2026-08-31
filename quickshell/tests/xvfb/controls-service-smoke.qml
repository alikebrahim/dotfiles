import QtQuick
import Quickshell
import Quickshell.Networking
import services as Services

ShellRoot {
  id: root

  readonly property string resultPath: Quickshell.env("QUATTRO_QS_TEST_RESULT")
  property var failures: []
  property int blockedMutationCount: 0

  Services.CommandTransport {
    id: blockedTransport
    fixtureMode: true
    onFinished: function(requestId, key, ok, output, error) {
      if (key.indexOf("safety.blocked-") === 0 && !ok && error === "mutations disabled")
        root.blockedMutationCount++
    }
  }

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
      "brightness.state": "acpi_video0,backlight,5,26%,19\n"
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
    id: headsetAudio
    property real volume: 0.45
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
    id: headsetNode
    property int id: 52
    property string name: "bluez_output.headset"
    property string description: "Headset"
    property string nickname: "Headset"
    property bool isSink: true
    property bool isStream: false
    property bool ready: true
    property var properties: ({})
    property QtObject audio: headsetAudio
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
    property var nodes: [outputNode, headsetNode, inputNode, streamNode, captureNode]
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
    property int receivedPskLength: 0
    signal connectionFailed(int reason)
    function connect() { connected = true; known = true; state = ConnectionState.Connected }
    function connectWithPsk(psk) { receivedPskLength = String(psk).length; connect() }
    function disconnect() { connected = false; state = ConnectionState.Disconnected }
    function forget() { known = false }
  }
  QtObject {
    id: knownNetwork
    property string name: "Saved Cafe"
    property bool connected: false
    property bool known: true
    property int state: ConnectionState.Disconnected
    property bool stateChanging: false
    property real signalStrength: 0.52
    property int security: WifiSecurityType.Wpa2Psk
    signal connectionFailed(int reason)
    function connect() { connected = true; state = ConnectionState.Connected }
    function connectWithPsk(psk) { connect() }
    function disconnect() { connected = false; state = ConnectionState.Disconnected }
    function forget() { known = false }
  }
  QtObject {
    id: wifiNetworks
    property var values: [homeNetwork, protectedNetwork, knownNetwork]
  }
  QtObject {
    id: wifiDevice
    property int type: DeviceType.Wifi
    property string name: "wlp4s0"
    property bool connected: homeNetwork.connected || protectedNetwork.connected || knownNetwork.connected
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
    property int connectCalls: 0
    property int disconnectCalls: 0
    property int pairCalls: 0
    property int forgetCalls: 0
    function connect() { connectCalls++; connected = true }
    function disconnect() { disconnectCalls++; connected = false }
    function pair() { pairCalls++; paired = true; bonded = true }
    function forget() { forgetCalls++; connected = false; paired = false; bonded = false; trusted = false }
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
    property int connectCalls: 0
    property int disconnectCalls: 0
    property int pairCalls: 0
    property int forgetCalls: 0
    function connect() { connectCalls++; connected = true }
    function disconnect() { disconnectCalls++; connected = false }
    function pair() { pairCalls++; paired = true; bonded = true }
    function forget() { forgetCalls++; connected = false; paired = false; bonded = false; trusted = false }
  }
  QtObject {
    id: availableSpeaker
    property string address: "33:44:55:66:77:88"
    property string deviceName: "Portable Speaker"
    property string name: "Portable Speaker"
    property string icon: "audio-speakers"
    property bool connected: false
    property bool paired: false
    property bool bonded: false
    property bool pairing: false
    property bool trusted: false
    property bool batteryAvailable: false
    property real battery: 0
    property int connectCalls: 0
    property int disconnectCalls: 0
    property int pairCalls: 0
    property int forgetCalls: 0
    function connect() { connectCalls++; connected = true }
    function disconnect() { disconnectCalls++; connected = false }
    function pair() { pairCalls++; pairing = true; paired = true; bonded = true; pairing = false }
    function forget() { forgetCalls++; connected = false; paired = false; bonded = false; trusted = false }
  }
  QtObject {
    id: uuidNoise
    property string address: "44:55:66:77:88:99"
    property string deviceName: "0000110b-0000-1000-8000-00805f9b34fb"
    property string name: "44:55:66:77:88:99"
    property string icon: ""
    property bool connected: false
    property bool paired: false
    property bool bonded: false
    property bool pairing: false
    property bool trusted: false
    property bool batteryAvailable: false
    property real battery: 0
    function connect() { connected = true }
    function disconnect() { connected = false }
    function pair() { paired = true; bonded = true }
    function forget() { paired = false; bonded = false; trusted = false }
  }
  QtObject {
    id: bluetoothDevices
    property var values: [connectedHeadphones, knownKeyboard, availableSpeaker, uuidNoise]
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
  Services.AudioService {
    id: lockedAudio
    transport: blockedTransport
    backend: audioBackend
    useNativeBackend: false
  }
  Services.NetworkService { id: network; transport: transport; backend: networkBackend }
  Services.NetworkService { id: lockedNetwork; transport: blockedTransport; backend: networkBackend }
  Services.BluetoothService { id: bluetooth; transport: transport; backend: bluetoothBackend }
  Services.BluetoothService { id: lockedBluetooth; transport: blockedTransport; backend: bluetoothBackend }
  Services.PowerService { id: power; transport: transport; refreshOnStart: false }
  Services.BrightnessService { id: brightness; transport: transport; refreshOnStart: false }

  function expect(condition, message) {
    if (!condition) failures.push(String(message))
  }

  function shellQuote(value) {
    return "'" + String(value).replace(/'/g, "'\\''") + "'"
  }

  function recordedCommand(actions, index) {
    return index >= 0 && index < actions.length && actions[index].command
      ? actions[index].command.join(" ")
      : ""
  }

  function finish() {
    var actions = transport.recordedActions
    var payload = JSON.stringify({
      ok: failures.length === 0,
      failures: failures,
      actionCount: actions.length,
      actions: actions,
      audio: {
        volume: audio.volume,
        muted: audio.muted,
        output: audio.currentOutput,
        outputs: audio.outputs.length,
        error: audio.error
      },
      network: { wifi: network.wifiEnabled, state: network.state, connection: network.connectionName, signal: network.signalStrength },
      bluetooth: {
        powered: bluetooth.powered,
        connectedName: bluetooth.connectedName,
        connectedCount: bluetooth.connectedCount,
        detailOpen: bluetooth.detailOpen,
        discovering: bluetooth.discovering,
        count: bluetooth.devices.length,
        pending: bluetooth.pending,
        error: bluetooth.error
      },
      power: {
        present: power.present,
        percentage: power.percentage,
        state: power.state,
        profile: power.profile,
        profiles: power.profiles.length
      },
      brightness: { percentage: brightness.percentage, device: brightness.device }
    })
    Quickshell.execDetached(["bash", "-lc", "printf '%s' " + shellQuote(payload) + " > " + shellQuote(resultPath)])
    Qt.callLater(Qt.quit)
  }

  Component.onCompleted: {
    audio.setDetailOpen(true)
    audio.refresh()
    network.setDetailOpen(true)
    network.refresh()
    bluetooth.setDetailOpen(true)
    bluetooth.refresh()
    power.refresh()
    brightness.refresh()
    blockedTransport.request("safety.blocked-audio", ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "5%+"], true)
    blockedTransport.request("safety.blocked-network", ["nmcli", "radio", "wifi", "off"], true)
    blockedTransport.request("safety.blocked-bluetooth", ["bluetoothctl", "power", "off"], true)
    blockedTransport.request("safety.blocked-power", ["tuned-adm", "profile", "performance"], true)
    blockedTransport.request("safety.blocked-brightness", ["brightnessctl", "set", "+5%"], true)
    blockedTransport.request("safety.blocked-manager", ["nm-connection-editor"], true, true)
  }

  Timer {
    interval: 100
    running: true
    repeat: false
    onTriggered: {
      root.expect(audio.volume === 65 && !audio.muted, "native audio output summary is derived from the default sink")
      root.expect(audio.currentOutput === "alsa_output.pci-main.analog-stereo" && audio.outputs.length === 2,
        "native audio detail snapshots include both output devices")
      root.expect(audio.inputs.length === 1 && audio.streams.length === 1 && audio.microphoneInUse,
        "native audio detail exposes input, playback stream, and microphone privacy state")
      root.expect(!lockedAudio.volumeUp() && lockedAudio.error.indexOf("read-only") !== -1,
        "native audio writes re-check the general mutation gate")
      root.expect(network.backendReady && network.wifiEnabled && network.state === "connected"
        && network.connectionName === "Home Wifi" && network.signalStrength === 78,
        "native NetworkManager summary follows the connected Wi-Fi object")
      root.expect(network.detailOpen && wifiDevice.scannerEnabled && network.networks.length === 3,
        "network rows and scanning attach only while Network detail is open")
      root.expect(!lockedNetwork.toggleWifi() && lockedNetwork.error.indexOf("read-only") !== -1,
        "native network writes re-check the general mutation gate")
      root.expect(bluetooth.backendReady && bluetooth.powered && bluetooth.connectedName === "Headphones"
        && bluetooth.connectedCount === 1,
        "native BlueZ summary follows connected device objects")
      root.expect(bluetooth.detailOpen && bluetooth.discovering && bluetooth.devices.length === 3
        && bluetooth.connectedDevices.length === 1 && bluetooth.knownDevices.length === 1
        && bluetooth.availableDevices.length === 1 && bluetooth.connectedDevices[0].battery === 80,
        "Bluetooth detail exposes bounded discovery, grouped rows, filtered names, and battery state")
      root.expect(!lockedBluetooth.togglePower() && lockedBluetooth.error.indexOf("read-only") !== -1,
        "native Bluetooth writes re-check the general mutation gate")
      root.expect(power.present && power.percentage === 73 && power.state === "discharging", "battery state parses")
      root.expect(power.profile === "balanced" && power.profiles.length === 3, "Tuned profiles parse")
      root.expect(brightness.percentage === 26 && brightness.device === "acpi_video0"
        && brightness.current === 5 && brightness.maximum === 19,
        "brightnessctl machine output parses as device,class,current,percentage,maximum")
      root.expect(!blockedTransport.allowMutations, "production transport defaults mutations to disabled")
      root.expect(root.blockedMutationCount === 6, "disabled transport rejects every C1-C5 mutation and detached manager launch")
      root.expect(blockedTransport.recordedActions.length === 0, "blocked mutations never reach the fixture dispatcher")

      var updatedFixtures = Object.assign({}, transport.fixtureResponses)
      updatedFixtures["power.active"] = "Current active profile: performance\n"
      updatedFixtures["brightness.state"] = "acpi_video0,backlight,7,37%,19\n"
      transport.fixtureResponses = updatedFixtures

      var protectedId = network.networkId(protectedNetwork)
      root.expect(network.requestCredentials(protectedId), "unknown PSK network opens the native credential lifecycle")
      network.credentialText = "fixture-secret"
      root.expect(network.submitCredentials(), "PSK submission starts a native NetworkManager action")
      network.checkPending()
      root.expect(protectedNetwork.receivedPskLength === 14
        && network.credentialText === "" && network.credentialNetworkId === ""
        && protectedNetwork.connected && !network.pending,
        "PSK is passed directly to the native API, wiped from service state, and confirmed by convergence")

      var knownId = network.networkId(knownNetwork)
      root.expect(network.forgetNetwork(knownId), "saved disconnected network can be forgotten natively")
      network.checkPending()
      root.expect(!knownNetwork.known && !network.pending, "forget completes only after native known-state convergence")

      root.expect(bluetooth.activateDevice(availableSpeaker.address),
        "unpaired Bluetooth device starts the native pair/trust/connect sequence")
      bluetooth.checkPending()
      root.expect(availableSpeaker.pairCalls === 1 && availableSpeaker.paired
        && availableSpeaker.trusted && availableSpeaker.connected && !bluetooth.pending,
        "pair/trust/connect completes only after each observed native state converges")
      root.expect(bluetooth.disconnectDevice(availableSpeaker.address),
        "connected Bluetooth device starts a native disconnect")
      bluetooth.checkPending()
      root.expect(!availableSpeaker.connected && availableSpeaker.disconnectCalls === 1 && !bluetooth.pending,
        "Bluetooth disconnect completes after connected state converges")
      root.expect(bluetooth.forgetDevice(knownKeyboard.address),
        "paired Bluetooth device starts a native forget")
      bluetooth.checkPending()
      root.expect(knownKeyboard.forgetCalls === 1 && !knownKeyboard.paired && !knownKeyboard.bonded
        && !knownKeyboard.trusted && !bluetooth.pending,
        "Bluetooth forget completes after remembered state is removed")

      audio.volumeUp()
      network.toggleWifi()
      bluetooth.togglePower()
      root.expect(power.setProfile("performance"), "allowlisted Tuned profile accepted")
      root.expect(!power.setProfile("../../bad"), "invalid Tuned profile rejected")
      brightness.increase()
      root.expect(!audio.setOutput("unknown"), "unknown audio output rejected")
      network.openManager()

      confirmationTimer.restart()
    }
  }

  Timer {
    id: confirmationTimer
    interval: 150
    repeat: false
    onTriggered: {
        root.expect(transport.recordedActions.length === 3, "only non-native fixture actions reach the command transport")
        root.expect(root.recordedCommand(transport.recordedActions, 0) === "tuned-adm profile performance", "Tuned profile action is validated")
        root.expect(root.recordedCommand(transport.recordedActions, 1) === "brightnessctl set 31%", "brightness coalesces to an absolute percent")
        root.expect(root.recordedCommand(transport.recordedActions, 2) === "nm-connection-editor"
          && transport.recordedActions.length > 2 && transport.recordedActions[2].detached,
          "network manager uses the gated detached-launch path")
        root.expect(audio.volume === 70 && !audio.pending, "native audio mutation is confirmed by observed node state")
        root.expect(!network.wifiEnabled && !network.pending,
          "native Wi-Fi radio mutation is confirmed by observed NetworkManager state")
        root.expect(!bluetooth.powered && !bluetooth.pending && !bluetooth.discovering,
          "native Bluetooth power mutation is confirmed and owned discovery is stopped")
        root.expect(power.profile === "performance", "power mutation is confirmed by a fresh read")
        root.expect(brightness.percentage === 37, "brightness mutation is confirmed by a fresh read")
        root.expect(!power.applyProfiles("malformed ???") && power.profiles.length === 3, "malformed power readback preserves last-known-good state")
        root.expect(!brightness.applyState("malformed") && brightness.percentage === 37, "malformed brightness readback preserves last-known-good state")

        var malformedFixtures = Object.assign({}, transport.fixtureResponses)
        malformedFixtures["power.profiles"] = "malformed ???"
        malformedFixtures["brightness.state"] = "malformed"
        transport.fixtureResponses = malformedFixtures
        audio.refresh()
        network.refresh()
        bluetooth.refresh()
        power.refresh()
        brightness.refresh()
        malformedReadbackTimer.restart()
    }
  }

  Timer {
    id: malformedReadbackTimer
    interval: 150
    repeat: false
    onTriggered: {
      root.expect(audio.volume === 70 && audio.error.indexOf("no longer available") !== -1
        && audio.error.indexOf("audio.") === -1,
        "native audio validation errors remain independent of command parser failures")
      root.expect(!network.wifiEnabled && network.error === "",
        "native network authority remains independent of command parser failures")
      root.expect(!bluetooth.powered && bluetooth.error === "",
        "native Bluetooth authority remains independent of command parser failures")
      root.expect(power.profiles.length === 3 && power.error.indexOf("power.profiles") !== -1, "power reports malformed readback and preserves state")
      root.expect(brightness.percentage === 37 && brightness.error.indexOf("brightness.state") !== -1, "brightness reports malformed readback and preserves state")
      network.setDetailOpen(false)
      root.expect(!wifiDevice.scannerEnabled && network.networks.length === 0 && network.credentialText === "",
        "closing Network detail disables scanning and clears transient state")
      bluetooth.setDetailOpen(false)
      root.expect(!bluetooth.discovering && bluetooth.devices.length === 0,
        "closing Bluetooth detail stops owned discovery and clears transient rows")
      root.finish()
    }
  }
}
