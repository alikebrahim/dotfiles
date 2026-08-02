import QtQuick
import Quickshell
import Quickshell.Io
import services as Services
import modules.bar as Bar

ShellRoot {
  id: root

  Services.AwesomeBridge {
    id: bridge
  }

  Services.CommandTransport {
    id: transport
    fixtureMode: true
    allowMutations: false
    fixtureResponses: ({
      "audio.status": "Volume: 0.40\nMuted: no\nDefault Sink: Test Sink\n",
      "network.status": "Test WiFi:wifi:connected:yes:70\n",
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
    bridge: bridge
    audioService: audio
    networkService: network
    bluetoothService: bluetooth
    powerService: power
    brightnessService: brightness
  }

  IpcHandler {
    target: "wmtest"

    function status(): string {
      return JSON.stringify({
        ready: true,
        barVisible: bar.visible,
        controlsVisible: bar.systemControls.visible,
        activeControl: bar.systemControls.activeControl
      })
    }

    function openAudio(): string {
      bar.systemControls.showControl("audio")
      return status()
    }

    function closeControls(): string {
      bar.systemControls.close()
      return status()
    }

    function hideBar(): string {
      bar.visibilityController.setVisible(false)
      return status()
    }

    function showBar(): string {
      bar.visibilityController.setVisible(true)
      return status()
    }

    function quit(): void {
      Qt.callLater(Qt.quit)
    }
  }

  Component.onCompleted: {
    var screenName = Quickshell.screens.length > 0 ? Quickshell.screens[0].name : ""
    bridge.applyRaw(JSON.stringify({
      primaryOutput: "xvfb-primary",
      focusedOutput: "xvfb-primary",
      outputs: [{ id: "xvfb-primary", name: screenName }],
      tags: [{ name: "1", selected: true, occupied: true, urgent: false }],
      clients: [],
      focusedTitle: "Xvfb integration",
      keyboardLayout: "us"
    }))
    audio.refresh()
    network.refresh()
    bluetooth.refresh()
    power.refresh()
    brightness.refresh()
  }

  Timer {
    interval: 30000
    running: true
    repeat: false
    onTriggered: Qt.quit()
  }
}
