import QtQuick
import Quickshell
import services as Services
import modules.bar as Bar
import modules.osd as Osd

ShellRoot {
  id: root

  readonly property string resultPath: Quickshell.env("QUATTRO_QS_TEST_RESULT")

  Services.ShellState { id: shellState }
  Services.AwesomeBridge { id: bridge }
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

  Services.AudioService { id: audio; transport: transport; backend: null; useNativeBackend: false }
  Services.NetworkService { id: network; transport: transport; backend: null }
  Services.BluetoothService { id: bluetooth; transport: transport; backend: null }
  Services.PowerService { id: power; transport: transport; refreshOnStart: false }
  Services.BrightnessService { id: brightness; transport: transport; refreshOnStart: false }

  Bar.PrimaryBar {
    id: bar
    shellState: shellState
    bridge: bridge
    audioService: audio
    networkService: network
    bluetoothService: bluetooth
    powerService: power
    brightnessService: brightness
  }

  Osd.Osd {
    id: osd
    bridge: bridge
  }

  function shellQuote(value) {
    return "'" + String(value).replace(/'/g, "'\\''") + "'"
  }

  function writeReady() {
    var payload = JSON.stringify({
      ok: bar.visible && bar.systemControls.panel.visible && osd.panel.visible,
      barContinuousBackground: bar.color.a > 0,
      barExclusiveZone: bar.exclusiveZone,
      controlPanelExclusiveZone: bar.systemControls.panel.exclusiveZone,
      osdExclusiveZone: osd.panel.exclusiveZone,
      osdFocusable: osd.panel.focusable
    })
    Quickshell.execDetached(["bash", "-lc", "printf '%s' " + shellQuote(payload) + " > " + shellQuote(resultPath)])
  }

  Component.onCompleted: {
    var name = Quickshell.screens.length > 0 ? Quickshell.screens[0].name : ""
    bridge.applyRaw(JSON.stringify({
      primaryOutput: "primary",
      focusedOutput: "primary",
      outputs: [{ id: "primary", name: name }],
      tags: [
        { name: "1", selected: true, occupied: true, urgent: false },
        { name: "2", selected: false, occupied: true, urgent: false },
        { name: "3", selected: false, occupied: false, urgent: true }
      ],
      focusedClient: { title: "Quattro X11 visual proof", class: "quickshell", screen: "primary" }
    }))
    audio.refresh()
    network.refresh()
    bluetooth.refresh()
    power.refresh()
    brightness.refresh()
  }

  Timer {
    interval: 150
    running: true
    repeat: false
    onTriggered: {
      bar.systemControls.openPanel()
      osd.showPayload({ type: "brightness", value: 80, max: 100, duration: 5000 })
      Qt.callLater(root.writeReady)
    }
  }

  Timer {
    interval: 60000
    running: true
    repeat: false
    onTriggered: Qt.quit()
  }

  Timer {
    interval: 2000
    running: true
    repeat: true
    onTriggered: osd.showPayload({ type: "brightness", value: 80, max: 100, duration: 5000 })
  }
}
