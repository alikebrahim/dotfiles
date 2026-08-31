import QtQuick
import QtQuick.Layouts
import "../../ui" as Ui
import "../../style" as ShellStyle

Item {
  id: root

  property string activeControl: "audio"
  property int cursorIndex: 0
  property bool cursorActive: false
  property string audioFocusSection: "output"
  property int audioSelectedIndex: -1
  property string networkFocusSection: "toggle"
  property string networkSelectedId: ""
  property bool networkForgetFocused: false
  property string bluetoothFocusSection: "toggle"
  property string bluetoothSelectedId: ""
  property bool bluetoothForgetFocused: false
  property var audio: null
  property var network: null
  property var bluetooth: null
  property var power: null
  property var brightness: null
  readonly property bool editorActive: Boolean(network && network.credentialOpen)
  signal keyboardFocusRequested()

  readonly property string panelTitle: {
    if (activeControl === "network") return "Network"
    if (activeControl === "bluetooth") return "Bluetooth"
    if (activeControl === "power") return "Power"
    if (activeControl === "brightness") return "Brightness"
    return "Audio"
  }
  readonly property var activeService: {
    if (activeControl === "network") return network
    if (activeControl === "bluetooth") return bluetooth
    if (activeControl === "power") return power
    if (activeControl === "brightness") return brightness
    return audio
  }
  readonly property var powerProfileChoices: {
    var available = power ? power.profiles : []
    var definitions = [
      { label: "Saver", token: "powersave" },
      { label: "Balanced", token: "balanced" },
      { label: "Performance", token: "throughput-performance" }
    ]
    var choices = []
    for (var i = 0; i < definitions.length; i++)
      if (available.indexOf(definitions[i].token) !== -1) choices.push(definitions[i])
    return choices
  }
  readonly property int targetCount: {
    if (activeControl === "audio") return 1
    if (activeControl === "network") return 2 + (network ? network.networks.length : 0)
    if (activeControl === "bluetooth") return 2 + (bluetooth ? bluetooth.devices.length : 0)
    if (activeControl === "power") return Math.max(1, powerProfileChoices.length)
    return 1
  }
  readonly property var audioVisibleSections: {
    var sections = ["output"]
    if (audio && (audio.inputAvailable || audio.inputs.length > 0)) sections.push("input")
    if (audio && audio.streams.length > 0) sections.push("streams")
    return sections
  }

  implicitHeight: Math.min(panelColumn.implicitHeight, ShellStyle.Metrics.popupMaxContentHeight)

  function audioIcon() {
    if (!audio || audio.muted) return "\ueee8"
    if (audio.volume >= 67) return "\uf028"
    if (audio.volume >= 34) return "\uf027"
    return "\uf026"
  }

  function networkIcon() {
    if (!network || !network.connectionName) return String.fromCodePoint(0xF092E)
    if (network.connectionType.indexOf("ethernet") !== -1) return String.fromCodePoint(0xF0200)
    var icons = [0xF092F, 0xF091F, 0xF0922, 0xF0925, 0xF0928]
    var index = Math.max(0, Math.min(4, Math.ceil(Math.max(0, network.signalStrength) / 20) - 1))
    return String.fromCodePoint(icons[index])
  }

  function wifiIconFor(strength) {
    var icons = [0xF092F, 0xF091F, 0xF0922, 0xF0925, 0xF0928]
    var index = Math.max(0, Math.min(4, Math.ceil(Math.max(0, Number(strength)) / 20) - 1))
    return String.fromCodePoint(icons[index])
  }

  function bluetoothIcon() {
    if (!bluetooth || !bluetooth.powered) return String.fromCodePoint(0xF00B2)
    return bluetooth.connectedName ? String.fromCodePoint(0xF00B1) : String.fromCodePoint(0xF00AF)
  }

  function powerIcon() {
    if (!power || !power.present) return ""
    var icons = [0xF007A, 0xF007B, 0xF007C, 0xF007D, 0xF007E, 0xF007F, 0xF0080, 0xF0081, 0xF0082, 0xF0079]
    return String.fromCodePoint(icons[Math.max(0, Math.min(9, Math.floor(power.percentage / 10)))])
  }

  function heroIcon() {
    if (activeControl === "network") return networkIcon()
    if (activeControl === "bluetooth") return bluetoothIcon()
    if (activeControl === "power") return powerIcon()
    if (activeControl === "brightness") return String.fromCodePoint(0xF0379)
    return audioIcon()
  }

  function heroTitle() {
    if (activeControl === "network") return network && network.connectionName ? network.connectionName : "Network"
    if (activeControl === "bluetooth") return "Bluetooth"
    if (activeControl === "power") return "Battery"
    if (activeControl === "brightness") return "Brightness"
    return "Audio"
  }

  function heroSubtitle() {
    if (activeControl === "audio") return !audio ? "Unavailable" : (audio.muted ? "Muted" : audio.volume + "% volume")
    if (activeControl === "network") {
      if (!network || !network.connectionName) return "Not connected"
      return network.signalStrength >= 0 ? network.signalStrength + "% signal" : network.state
    }
    if (activeControl === "bluetooth") {
      if (!bluetooth || !bluetooth.available) return "No adapter"
      if (!bluetooth.powered) return "Turned off"
      if (bluetooth.connectedCount > 1) return bluetooth.connectedCount + " devices connected"
      if (bluetooth.connectedCount === 1) return bluetooth.connectedName
      return bluetooth.discovering ? "Scanning for devices" : "Ready to connect"
    }
    if (activeControl === "power") return !power ? "Unavailable" : ((power.state || "unknown") + (power.profile ? " · " + power.profile : ""))
    return brightness && brightness.available ? brightness.percentage + "% brightness" : "Fixed brightness"
  }

  function heroValue() {
    return activeControl === "power" && power && power.present ? power.percentage + "%" : ""
  }

  function clampCursor() {
    cursorIndex = Math.max(0, Math.min(Math.max(0, targetCount - 1), cursorIndex))
  }

  function audioOutputLabel() {
    if (!audio) return "Output unavailable"
    for (var i = 0; i < audio.outputs.length; i++) {
      var output = audio.outputs[i]
      if (String(output.name || "") === String(audio.currentOutput || ""))
        return String(output.description || output.name || "Current output")
    }
    return audio.currentOutput || "No output selected"
  }

  function audioSectionCount(section) {
    if (!audio) return 0
    if (section === "output") return audio.outputs.length
    if (section === "input") return audio.inputs.length
    if (section === "streams") return audio.streams.length
    return 0
  }

  function audioSectionHasSlider(section) {
    if (section === "output") return true
    if (section === "input") return audio && audio.inputAvailable
    return false
  }

  function resetAudioCursor() {
    audioFocusSection = "output"
    audioSelectedIndex = -1
  }

  function networkRowIndex(identity) {
    if (!network) return -1
    var requested = String(identity || "")
    for (var i = 0; i < network.networks.length; i++)
      if (String(network.networks[i].id || "") === requested) return i
    return -1
  }

  function resetNetworkCursor() {
    networkFocusSection = "toggle"
    networkSelectedId = ""
    networkForgetFocused = false
  }

  function networkCursorPosition() {
    if (networkFocusSection === "manager") return (network ? network.networks.length : 0) + 1
    if (networkFocusSection !== "network") return 0
    var index = networkRowIndex(networkSelectedId)
    return index < 0 ? 0 : index + 1
  }

  function setNetworkCursorPosition(position) {
    var count = network ? network.networks.length : 0
    var next = Math.max(0, Math.min(count + 1, position))
    networkForgetFocused = false
    if (next === 0) {
      networkFocusSection = "toggle"
      networkSelectedId = ""
    } else if (next === count + 1) {
      networkFocusSection = "manager"
      networkSelectedId = ""
    } else {
      networkFocusSection = "network"
      networkSelectedId = String(network.networks[next - 1].id || "")
    }
  }

  function reconcileNetworkCursor() {
    if (networkFocusSection === "network" && networkRowIndex(networkSelectedId) < 0)
      resetNetworkCursor()
  }

  function bluetoothRowIndex(identity) {
    if (!bluetooth) return -1
    var requested = String(identity || "")
    for (var i = 0; i < bluetooth.devices.length; i++)
      if (String(bluetooth.devices[i].id || "") === requested) return i
    return -1
  }

  function resetBluetoothCursor() {
    bluetoothFocusSection = "toggle"
    bluetoothSelectedId = ""
    bluetoothForgetFocused = false
  }

  function bluetoothCursorPosition() {
    if (bluetoothFocusSection === "scan") return 1
    if (bluetoothFocusSection !== "device") return 0
    var index = bluetoothRowIndex(bluetoothSelectedId)
    return index < 0 ? 0 : index + 2
  }

  function setBluetoothCursorPosition(position) {
    var count = bluetooth ? bluetooth.devices.length : 0
    var next = Math.max(0, Math.min(count + 1, position))
    bluetoothForgetFocused = false
    if (next === 0) {
      bluetoothFocusSection = "toggle"
      bluetoothSelectedId = ""
    } else if (next === 1) {
      bluetoothFocusSection = "scan"
      bluetoothSelectedId = ""
    } else {
      bluetoothFocusSection = "device"
      bluetoothSelectedId = String(bluetooth.devices[next - 2].id || "")
    }
  }

  function reconcileBluetoothCursor() {
    if (bluetoothFocusSection === "device" && bluetoothRowIndex(bluetoothSelectedId) < 0)
      resetBluetoothCursor()
  }

  function moveBluetoothCursor(dx, dy) {
    if (!bluetooth) return
    if (dx !== 0 && bluetoothFocusSection === "device") {
      var rowIndex = bluetoothRowIndex(bluetoothSelectedId)
      var row = rowIndex >= 0 ? bluetooth.devices[rowIndex] : null
      bluetoothForgetFocused = Boolean(dx > 0 && row && row.section !== "available")
      return
    }
    if (dy !== 0)
      setBluetoothCursorPosition(bluetoothCursorPosition() + (dy > 0 ? 1 : -1))
  }

  function activateBluetoothCursor() {
    if (!bluetooth || !bluetooth.actionsEnabled || bluetooth.pending) return
    if (bluetoothFocusSection === "toggle") bluetooth.togglePower()
    else if (bluetoothFocusSection === "scan") bluetooth.startDiscovery()
    else if (bluetoothFocusSection === "device" && bluetoothSelectedId !== "") {
      if (bluetoothForgetFocused) bluetooth.forgetDevice(bluetoothSelectedId)
      else bluetooth.activateDevice(bluetoothSelectedId)
    }
  }

  function bluetoothRowMeta(row) {
    if (!row || !bluetooth) return ""
    var identity = String(row.id || "")
    var status = bluetooth.rowStatus(identity)
    if ((bluetooth.pending && bluetooth.pendingAddress === identity)
        || (bluetooth.error && bluetooth.errorDeviceId === identity)) return status
    if (row.connected && row.batteryAvailable) return row.battery + "%"
    if (status !== "") return status
    return row.section === "available" ? "Available" : "Paired"
  }

  function bluetoothSectionLabel(section) {
    if (section === "connected") return "Connected"
    if (section === "known") return "Paired"
    return "Available"
  }

  function moveNetworkCursor(dx, dy) {
    if (!network) return
    if (dx !== 0 && networkFocusSection === "network") {
      var rowIndex = networkRowIndex(networkSelectedId)
      var row = rowIndex >= 0 ? network.networks[rowIndex] : null
      networkForgetFocused = Boolean(dx > 0 && row && row.known && !row.connected)
      return
    }
    if (dy !== 0)
      setNetworkCursorPosition(networkCursorPosition() + (dy > 0 ? 1 : -1))
  }

  function activateNetworkCursor() {
    if (!network || !network.actionsEnabled || network.pending) return
    if (networkFocusSection === "toggle") network.toggleWifi()
    else if (networkFocusSection === "manager") network.openManager()
    else if (networkFocusSection === "network" && networkSelectedId !== "") {
      if (networkForgetFocused) network.forgetNetwork(networkSelectedId)
      else network.activateNetwork(networkSelectedId)
    }
  }

  function moveAudioCursor(delta) {
    var sections = audioVisibleSections
    if (!sections.length || delta === 0) return
    var sectionIndex = sections.indexOf(audioFocusSection)
    if (sectionIndex < 0) {
      resetAudioCursor()
      return
    }

    var count = audioSectionCount(audioFocusSection)
    var floor = audioSectionHasSlider(audioFocusSection) ? -1 : 0
    var last = count - 1
    if (delta > 0) {
      if (audioSelectedIndex < last) {
        audioSelectedIndex++
        return
      }
      if (sectionIndex < sections.length - 1) {
        audioFocusSection = sections[sectionIndex + 1]
        audioSelectedIndex = audioSectionHasSlider(audioFocusSection) ? -1 : 0
      }
    } else {
      if (audioSelectedIndex > floor) {
        audioSelectedIndex--
        return
      }
      if (sectionIndex > 0) {
        audioFocusSection = sections[sectionIndex - 1]
        var previousLast = audioSectionCount(audioFocusSection) - 1
        audioSelectedIndex = previousLast >= 0 ? previousLast : (audioSectionHasSlider(audioFocusSection) ? -1 : 0)
      }
    }
  }

  function adjustFocusedAudio(direction) {
    if (!audio || !audio.actionsEnabled || audio.pending || direction === 0) return
    var step = direction > 0 ? 5 : -5
    if (audioFocusSection === "output" && audioSelectedIndex === -1) audio.setVolume(audio.volume + step)
    else if (audioFocusSection === "input" && audioSelectedIndex === -1) audio.setInputVolume(audio.inputVolume + step)
    else if (audioFocusSection === "streams" && audioSelectedIndex >= 0 && audioSelectedIndex < audio.streams.length) {
      var stream = audio.streams[audioSelectedIndex]
      audio.setStreamVolume(stream.id, stream.volume + step)
    }
  }

  function activateAudioCursor() {
    if (!audio || !audio.actionsEnabled || audio.pending) return
    if (audioFocusSection === "output") {
      if (audioSelectedIndex === -1) audio.toggleMute()
      else if (audioSelectedIndex < audio.outputs.length) audio.setOutput(audio.outputs[audioSelectedIndex].id)
    } else if (audioFocusSection === "input") {
      if (audioSelectedIndex === -1) audio.toggleInputMute()
      else if (audioSelectedIndex < audio.inputs.length) audio.setInput(audio.inputs[audioSelectedIndex].id)
    } else if (audioFocusSection === "streams" && audioSelectedIndex >= 0 && audioSelectedIndex < audio.streams.length) {
      audio.toggleStreamMute(audio.streams[audioSelectedIndex].id)
    }
  }

  function muteFocusedAudio() {
    if (!cursorActive) return
    activateAudioCursor()
  }

  function ensureAudioCursorVisible(item) {
    if (!item || !scrollArea) return
    var point = item.mapToItem(panelColumn, 0, 0)
    var top = point.y
    var bottom = top + item.height
    if (top < scrollArea.contentY) scrollArea.contentY = Math.max(0, top - 6)
    else if (bottom > scrollArea.contentY + scrollArea.height)
      scrollArea.contentY = Math.min(Math.max(0, scrollArea.contentHeight - scrollArea.height), bottom - scrollArea.height + 6)
  }

  function moveCursor(dx, dy) {
    var delta = dy !== 0 ? dy : dx
    if (delta !== 0 && !cursorActive) {
      cursorActive = true
      if (activeControl === "audio") resetAudioCursor()
      else if (activeControl === "network") resetNetworkCursor()
      else if (activeControl === "bluetooth") resetBluetoothCursor()
    }
    if (activeControl === "audio") {
      if (dy !== 0) moveAudioCursor(dy)
      else if (dx !== 0) adjustFocusedAudio(dx)
      return
    }
    if (activeControl === "network") {
      moveNetworkCursor(dx, dy)
      return
    }
    if (activeControl === "bluetooth") {
      moveBluetoothCursor(dx, dy)
      return
    }
    if (activeControl === "brightness" && delta !== 0) {
      if (brightness && brightness.actionsEnabled) delta > 0 ? brightness.increase() : brightness.decrease()
      return
    }
    if (targetCount > 1 && delta !== 0) {
      cursorIndex = Math.max(0, Math.min(targetCount - 1, cursorIndex + (delta > 0 ? 1 : -1)))
    }
  }

  function handleTextKey(text) {
    var key = String(text || "").toLowerCase()
    if (activeControl === "audio" && key === "m") muteFocusedAudio()
    else if (activeControl === "network" && key === "w" && network && network.actionsEnabled) network.toggleWifi()
    else if (activeControl === "bluetooth" && key === "b" && bluetooth && bluetooth.actionsEnabled) bluetooth.togglePower()
    else if (activeControl === "bluetooth" && key === "s" && bluetooth && bluetooth.actionsEnabled) bluetooth.startDiscovery()
  }

  function activateCursor() {
    if (activeControl === "audio") {
      activateAudioCursor()
    } else if (activeControl === "network") {
      activateNetworkCursor()
    } else if (activeControl === "bluetooth") {
      activateBluetoothCursor()
    } else if (activeControl === "power") {
      if (power && power.actionsEnabled && cursorIndex < powerProfileChoices.length)
        power.setProfile(String(powerProfileChoices[cursorIndex].token))
    }
  }

  function refreshActive() {
    cursorIndex = 0
    cursorActive = false
    resetAudioCursor()
    resetNetworkCursor()
    resetBluetoothCursor()
    scrollArea.contentY = 0
    if (activeService && typeof activeService.refresh === "function") activeService.refresh()
  }

  onActiveControlChanged: refreshActive()
  onTargetCountChanged: clampCursor()

  Connections {
    target: root.network
    function onNetworksChanged() { root.reconcileNetworkCursor() }
    function onPanelFocusRequested() { root.keyboardFocusRequested() }
  }

  Connections {
    target: root.bluetooth
    function onDevicesChanged() { root.reconcileBluetoothCursor() }
  }

  Flickable {
    id: scrollArea
    anchors.fill: parent
    clip: true
    contentWidth: width
    contentHeight: panelColumn.implicitHeight
    boundsBehavior: Flickable.StopAtBounds

    Column {
      id: panelColumn
      width: scrollArea.width
      spacing: ShellStyle.Metrics.panelGap

    Ui.PanelHero {
      width: parent.width
      iconText: root.heroIcon()
      title: root.heroTitle()
      subtitle: root.heroSubtitle()
      valueText: root.heroValue()
      dimIcon: root.activeService === null
    }

    Item {
      visible: root.activeControl === "power" && root.power && root.power.present
      width: parent.width
      implicitHeight: visible ? 8 : 0

      Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: ShellStyle.Palette.track
      }
      Rectangle {
        height: parent.height
        width: parent.width * Math.max(0, Math.min(1, root.power ? root.power.percentage / 100 : 0))
        radius: height / 2
        color: ShellStyle.Palette.foreground
        Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
      }
    }

    Ui.PanelSeparator { width: parent.width }

    Column {
      visible: root.activeControl === "audio"
      width: parent.width
      spacing: ShellStyle.Metrics.rowGap

      Item {
        width: parent.width
        implicitHeight: Math.max(audioHeader.implicitHeight, audioPercent.implicitHeight)
        Ui.PanelSectionHeader { id: audioHeader; label: "Output"; anchors.left: parent.left }
        Text {
          id: audioPercent
          textFormat: Text.PlainText
          anchors.right: parent.right
          text: root.audio ? root.audio.volume + "%" : "—"
          color: ShellStyle.Palette.muted
          font.family: ShellStyle.Metrics.fontFamily
          font.pixelSize: ShellStyle.Metrics.captionSize
          font.bold: true
        }
      }

      Ui.PanelSlider {
        id: outputSlider
        width: parent.width
        value: root.audio ? root.audio.volume : 0
        enabled: root.audio && root.audio.available && root.audio.actionsEnabled && !root.audio.pending
        hasCursor: root.cursorActive && root.audioFocusSection === "output" && root.audioSelectedIndex === -1
        onHasCursorChanged: if (hasCursor) root.ensureAudioCursorVisible(outputSlider)
        onHovered: function(value) {
          if (value) {
            root.cursorActive = true
            root.audioFocusSection = "output"
            root.audioSelectedIndex = -1
          }
        }
        onCommitted: function(value) { if (root.audio) root.audio.setVolume(value) }
      }

      Repeater {
        model: root.audio ? root.audio.outputs : []
        delegate: Ui.PanelButton {
          required property var modelData
          required property int index
          width: parent.width
          iconText: String(modelData.icon || "")
          text: String(modelData.description || modelData.name || "Output")
          current: Boolean(modelData.current)
          hasCursor: root.cursorActive && root.audioFocusSection === "output" && root.audioSelectedIndex === index
          enabled: root.audio && root.audio.actionsEnabled && !root.audio.pending
          onHasCursorChanged: if (hasCursor) root.ensureAudioCursorVisible(this)
          onHovered: function(value) {
            if (value) {
              root.cursorActive = true
              root.audioFocusSection = "output"
              root.audioSelectedIndex = index
            }
          }
          onClicked: if (root.audio) root.audio.setOutput(modelData.id)
        }
      }

      Ui.PanelSeparator {
        visible: root.audio && (root.audio.inputAvailable || root.audio.inputs.length > 0)
        width: parent.width
      }

      Item {
        visible: root.audio && (root.audio.inputAvailable || root.audio.inputs.length > 0)
        width: parent.width
        implicitHeight: visible ? Math.max(inputHeader.implicitHeight, inputPercent.implicitHeight) : 0
        Ui.PanelSectionHeader { id: inputHeader; label: "Input"; anchors.left: parent.left }
        Text {
          id: inputPercent
          textFormat: Text.PlainText
          anchors.right: parent.right
          text: root.audio && root.audio.inputAvailable ? root.audio.inputVolume + "%" : "—"
          color: ShellStyle.Palette.muted
          font.family: ShellStyle.Metrics.fontFamily
          font.pixelSize: ShellStyle.Metrics.captionSize
          font.bold: true
        }
      }

      Ui.PanelSlider {
        id: inputSlider
        visible: root.audio && root.audio.inputAvailable
        width: parent.width
        value: root.audio ? root.audio.inputVolume : 0
        enabled: root.audio && root.audio.inputAvailable && root.audio.actionsEnabled && !root.audio.pending
        hasCursor: root.cursorActive && root.audioFocusSection === "input" && root.audioSelectedIndex === -1
        onHasCursorChanged: if (hasCursor) root.ensureAudioCursorVisible(inputSlider)
        onHovered: function(value) {
          if (value) {
            root.cursorActive = true
            root.audioFocusSection = "input"
            root.audioSelectedIndex = -1
          }
        }
        onCommitted: function(value) { if (root.audio) root.audio.setInputVolume(value) }
      }

      Rectangle {
        visible: root.audio && root.audio.inputAvailable
        width: parent.width
        implicitHeight: visible ? 5 : 0
        radius: height / 2
        color: ShellStyle.Palette.track
        opacity: root.audio && root.audio.inputMuted ? 0.35 : 1

        Rectangle {
          height: parent.height
          width: parent.width * (root.audio ? root.audio.inputPeak : 0)
          radius: parent.radius
          color: ShellStyle.Palette.foreground
          Behavior on width { NumberAnimation { duration: 70 } }
        }
      }

      Repeater {
        model: root.audio ? root.audio.inputs : []
        delegate: Ui.PanelButton {
          required property var modelData
          required property int index
          width: parent.width
          iconText: String(modelData.icon || "")
          text: String(modelData.description || modelData.name || "Input")
          current: Boolean(modelData.current)
          hasCursor: root.cursorActive && root.audioFocusSection === "input" && root.audioSelectedIndex === index
          enabled: root.audio && root.audio.actionsEnabled && !root.audio.pending
          onHasCursorChanged: if (hasCursor) root.ensureAudioCursorVisible(this)
          onHovered: function(value) {
            if (value) {
              root.cursorActive = true
              root.audioFocusSection = "input"
              root.audioSelectedIndex = index
            }
          }
          onClicked: if (root.audio) root.audio.setInput(modelData.id)
        }
      }

      Ui.PanelSeparator {
        visible: root.audio && root.audio.streams.length > 0
        width: parent.width
      }

      Ui.PanelSectionHeader {
        visible: root.audio && root.audio.streams.length > 0
        label: "Applications"
      }

      Repeater {
        model: root.audio ? root.audio.streams : []
        delegate: Item {
          id: streamRow
          required property var modelData
          required property int index
          readonly property bool hasCursor: root.cursorActive
            && root.audioFocusSection === "streams"
            && root.audioSelectedIndex === index
          width: parent.width
          implicitHeight: streamColumn.implicitHeight + 12
          onHasCursorChanged: if (hasCursor) root.ensureAudioCursorVisible(streamRow)

          Rectangle {
            anchors.fill: parent
            radius: ShellStyle.Metrics.cornerRadius
            color: streamRow.hasCursor ? ShellStyle.Palette.hoverWash : ShellStyle.Palette.normalWash
            border.width: 1
            border.color: streamRow.hasCursor ? ShellStyle.Palette.hoverBorder : ShellStyle.Palette.controlBorder
          }

          Column {
            id: streamColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            spacing: 3

            Row {
              width: parent.width
              spacing: ShellStyle.Metrics.labelGap

              Text {
                id: streamMute
                width: 24
                text: streamRow.modelData.muted ? String.fromCodePoint(0xF075F) : String.fromCodePoint(0xF057E)
                textFormat: Text.PlainText
                color: ShellStyle.Palette.foreground
                font.family: ShellStyle.Metrics.fontFamily
                font.pixelSize: ShellStyle.Metrics.titleSize
                horizontalAlignment: Text.AlignHCenter
                opacity: streamRow.modelData.muted ? 0.5 : 1

                TapHandler {
                  enabled: root.audio && root.audio.actionsEnabled && !root.audio.pending
                  onTapped: if (root.audio) root.audio.toggleStreamMute(streamRow.modelData.id)
                }
              }

              Text {
                width: Math.max(0, parent.width - streamMute.width - streamPercent.width - parent.spacing * 2)
                text: String(streamRow.modelData.description || streamRow.modelData.name || "Application")
                textFormat: Text.PlainText
                color: ShellStyle.Palette.foreground
                font.family: ShellStyle.Metrics.fontFamily
                font.pixelSize: ShellStyle.Metrics.bodySmallSize
                font.weight: Font.Medium
                elide: Text.ElideRight
              }

              Text {
                id: streamPercent
                width: 42
                text: Math.round(Number(streamRow.modelData.volume || 0)) + "%"
                textFormat: Text.PlainText
                color: ShellStyle.Palette.muted
                font.family: ShellStyle.Metrics.fontFamily
                font.pixelSize: ShellStyle.Metrics.captionSize
                font.bold: true
                horizontalAlignment: Text.AlignRight
              }
            }

            Ui.PanelSlider {
              width: parent.width
              minimum: 0
              maximum: 150
              value: Number(streamRow.modelData.volume || 0)
              enabled: root.audio && root.audio.actionsEnabled && !root.audio.pending
              hasCursor: streamRow.hasCursor
              onCommitted: function(value) {
                if (root.audio) root.audio.setStreamVolume(streamRow.modelData.id, value)
              }
            }
          }

          HoverHandler {
            onHoveredChanged: if (hovered) {
              root.cursorActive = true
              root.audioFocusSection = "streams"
              root.audioSelectedIndex = streamRow.index
            }
          }
        }
      }
    }

    Column {
      visible: root.activeControl === "network"
      width: parent.width
      spacing: ShellStyle.Metrics.rowGap

      Ui.PanelSectionHeader { label: "Wi-Fi" }
      Ui.PanelButton {
        width: parent.width
        iconText: root.networkIcon()
        text: root.network && root.network.wifiEnabled ? "Turn Wi-Fi off" : "Turn Wi-Fi on"
        current: root.network && root.network.wifiEnabled
        hasCursor: root.cursorActive && root.networkFocusSection === "toggle"
        enabled: root.network && root.network.backendReady && root.network.wifiHardwareEnabled
          && root.network.actionsEnabled && !root.network.pending
        onHovered: function(value) {
          if (value) {
            root.cursorActive = true
            root.networkFocusSection = "toggle"
            root.networkSelectedId = ""
            root.networkForgetFocused = false
          }
        }
        onClicked: if (root.network) root.network.toggleWifi()
      }

      Text {
        visible: root.network && (!root.network.wifiDevice || !root.network.wifiHardwareEnabled)
        width: parent.width
        text: !root.network || !root.network.backendReady
          ? "NetworkManager unavailable"
          : (!root.network.wifiDevice ? "No Wi-Fi adapter" : "Wi-Fi hardware unavailable")
        textFormat: Text.PlainText
        color: ShellStyle.Palette.muted
        font.family: ShellStyle.Metrics.fontFamily
        font.pixelSize: ShellStyle.Metrics.bodySmallSize
        horizontalAlignment: Text.AlignHCenter
      }

      Ui.PanelSectionHeader {
        visible: root.network && root.network.wifiDevice && root.network.wifiEnabled
        label: "Available networks"
      }

      Repeater {
        model: root.network ? root.network.networks : []

        delegate: Column {
          id: networkRow
          required property var modelData
          required property int index
          width: parent.width
          spacing: ShellStyle.Metrics.rowGap

          readonly property bool selected: root.networkFocusSection === "network"
            && root.networkSelectedId === String(modelData.id || "")
          readonly property bool forgetAvailable: Boolean(modelData.known && !modelData.connected)
          readonly property string status: root.network ? root.network.rowStatus(modelData.id) : ""

          Row {
            width: parent.width
            spacing: 6

            Item {
              id: networkMain
              width: parent.width - (forgetButton.visible ? forgetButton.width + parent.spacing : 0)
              implicitHeight: ShellStyle.Metrics.controlHeight
              opacity: root.network && root.network.actionsEnabled && !root.network.pending ? 1 : 0.72

              Rectangle {
                anchors.fill: parent
                radius: ShellStyle.Metrics.cornerRadius
                color: networkRow.modelData.connected
                  ? ShellStyle.Palette.selectedWash
                  : ((networkPointer.hovered || (networkRow.selected && !root.networkForgetFocused))
                    ? ShellStyle.Palette.hoverWash
                    : ShellStyle.Palette.normalWash)
                border.width: networkRow.modelData.connected ? 0 : 1
                border.color: (networkPointer.hovered || (networkRow.selected && !root.networkForgetFocused))
                  ? ShellStyle.Palette.hoverBorder
                  : ShellStyle.Palette.controlBorder
              }

              Text {
                id: wifiGlyph
                anchors.left: parent.left
                anchors.leftMargin: ShellStyle.Metrics.controlPaddingX
                anchors.verticalCenter: parent.verticalCenter
                text: root.wifiIconFor(networkRow.modelData.signal)
                textFormat: Text.PlainText
                color: ShellStyle.Palette.foreground
                font.family: ShellStyle.Metrics.fontFamily
                font.pixelSize: ShellStyle.Metrics.titleSize
              }

              Text {
                anchors.left: wifiGlyph.right
                anchors.right: networkMeta.left
                anchors.leftMargin: ShellStyle.Metrics.labelGap
                anchors.rightMargin: ShellStyle.Metrics.labelGap
                anchors.verticalCenter: parent.verticalCenter
                text: String(networkRow.modelData.ssid || "Hidden")
                textFormat: Text.PlainText
                color: ShellStyle.Palette.foreground
                elide: Text.ElideRight
                font.family: ShellStyle.Metrics.fontFamily
                font.pixelSize: ShellStyle.Metrics.bodySmallSize
                font.weight: Font.Medium
              }

              Text {
                id: networkMeta
                anchors.right: parent.right
                anchors.rightMargin: ShellStyle.Metrics.controlPaddingX
                anchors.verticalCenter: parent.verticalCenter
                text: networkRow.status !== ""
                  ? networkRow.status
                  : (networkRow.modelData.protected ? "LOCK · " : "") + networkRow.modelData.signal + "%"
                textFormat: Text.PlainText
                color: root.network && root.network.errorNetworkId === String(networkRow.modelData.id || "")
                  ? ShellStyle.Palette.urgent
                  : ShellStyle.Palette.muted
                font.family: ShellStyle.Metrics.fontFamily
                font.pixelSize: ShellStyle.Metrics.captionSize
                font.bold: true
              }

              HoverHandler {
                id: networkPointer
                onHoveredChanged: if (hovered) {
                  root.cursorActive = true
                  root.networkFocusSection = "network"
                  root.networkSelectedId = String(networkRow.modelData.id || "")
                  root.networkForgetFocused = false
                }
              }
              TapHandler {
                enabled: root.network && root.network.actionsEnabled && !root.network.pending
                acceptedButtons: Qt.LeftButton
                onTapped: root.network.activateNetwork(networkRow.modelData.id)
              }
            }

            Ui.PanelButton {
              id: forgetButton
              visible: networkRow.forgetAvailable
              width: ShellStyle.Metrics.controlHeight
              iconText: String.fromCodePoint(0xF0A7A)
              hasCursor: root.cursorActive && networkRow.selected && root.networkForgetFocused
              enabled: root.network && root.network.actionsEnabled && !root.network.pending
              onHovered: function(value) {
                if (value) {
                  root.cursorActive = true
                  root.networkFocusSection = "network"
                  root.networkSelectedId = String(networkRow.modelData.id || "")
                  root.networkForgetFocused = true
                }
              }
              onClicked: if (root.network) root.network.forgetNetwork(networkRow.modelData.id)
            }
          }

          Column {
            visible: root.network
              && root.network.credentialNetworkId === String(networkRow.modelData.id || "")
            width: parent.width
            spacing: ShellStyle.Metrics.rowGap

            Text {
              width: parent.width
              text: root.network && root.network.errorNetworkId === String(networkRow.modelData.id || "")
                && root.network.error !== ""
                ? root.network.error
                : "Enter the passphrase for " + String(networkRow.modelData.ssid || "this network")
              textFormat: Text.PlainText
              color: root.network && root.network.errorNetworkId === String(networkRow.modelData.id || "")
                && root.network.error !== ""
                ? ShellStyle.Palette.urgent
                : ShellStyle.Palette.muted
              wrapMode: Text.WordWrap
              font.family: ShellStyle.Metrics.fontFamily
              font.pixelSize: ShellStyle.Metrics.bodySmallSize
            }

            Ui.PanelTextField {
              id: passphraseField
              width: parent.width
              password: true
              placeholderText: "Passphrase"
              enabled: root.network && root.network.actionsEnabled && !root.network.pending
              text: visible && root.network ? root.network.credentialText : ""
              onTextChanged: if (visible && root.network && text !== root.network.credentialText)
                root.network.credentialText = text
              onAccepted: if (root.network) root.network.submitCredentials()
              onCancelled: if (root.network) root.network.cancelCredentials()
              onVisibleChanged: if (visible) Qt.callLater(focusEditor)
            }

            Row {
              width: parent.width
              spacing: 6
              readonly property real cellWidth: (width - spacing) / 2

              Ui.PanelButton {
                width: parent.cellWidth
                text: "Connect"
                enabled: root.network && root.network.actionsEnabled
                  && !root.network.pending && passphraseField.text.length > 0
                onClicked: if (root.network) root.network.submitCredentials()
              }
              Ui.PanelButton {
                width: parent.cellWidth
                text: "Cancel"
                enabled: root.network && !root.network.pending
                onClicked: if (root.network) root.network.cancelCredentials()
              }
            }
          }
        }
      }

      Ui.PanelButton {
        width: parent.width
        text: "Open connection manager"
        hasCursor: root.cursorActive && root.networkFocusSection === "manager"
        enabled: root.network && root.network.actionsEnabled && !root.network.pending
        onHovered: function(value) {
          if (value) {
            root.cursorActive = true
            root.networkFocusSection = "manager"
            root.networkSelectedId = ""
            root.networkForgetFocused = false
          }
        }
        onClicked: if (root.network) root.network.openManager()
      }
    }

    Column {
      visible: root.activeControl === "bluetooth"
      width: parent.width
      spacing: ShellStyle.Metrics.rowGap

      Ui.PanelSectionHeader { label: "Adapter" }
      Ui.PanelButton {
        width: parent.width
        iconText: root.bluetoothIcon()
        text: root.bluetooth && root.bluetooth.powered ? "Turn Bluetooth off" : "Turn Bluetooth on"
        current: root.bluetooth && root.bluetooth.powered
        hasCursor: root.cursorActive && root.bluetoothFocusSection === "toggle"
        enabled: root.bluetooth && root.bluetooth.available && root.bluetooth.actionsEnabled
          && !root.bluetooth.pending
        onHovered: function(value) {
          if (value) {
            root.cursorActive = true
            root.bluetoothFocusSection = "toggle"
            root.bluetoothSelectedId = ""
            root.bluetoothForgetFocused = false
          }
        }
        onClicked: if (root.bluetooth) root.bluetooth.togglePower()
      }

      Ui.PanelButton {
        visible: root.bluetooth && root.bluetooth.available && root.bluetooth.powered
        width: parent.width
        iconText: String.fromCodePoint(0xF0450)
        text: root.bluetooth && root.bluetooth.discovering ? "Scanning for devices…" : "Scan for devices"
        current: root.bluetooth && root.bluetooth.discovering
        hasCursor: root.cursorActive && root.bluetoothFocusSection === "scan"
        enabled: root.bluetooth && root.bluetooth.actionsEnabled && !root.bluetooth.pending
          && !root.bluetooth.discovering
        onHovered: function(value) {
          if (value) {
            root.cursorActive = true
            root.bluetoothFocusSection = "scan"
            root.bluetoothSelectedId = ""
            root.bluetoothForgetFocused = false
          }
        }
        onClicked: if (root.bluetooth) root.bluetooth.startDiscovery()
      }

      Text {
        visible: !root.bluetooth || !root.bluetooth.backendReady || !root.bluetooth.available
        width: parent.width
        text: !root.bluetooth || !root.bluetooth.backendReady
          ? "BlueZ backend unavailable"
          : "No Bluetooth adapter"
        textFormat: Text.PlainText
        color: ShellStyle.Palette.muted
        font.family: ShellStyle.Metrics.fontFamily
        font.pixelSize: ShellStyle.Metrics.bodySmallSize
        horizontalAlignment: Text.AlignHCenter
      }

      Repeater {
        model: root.bluetooth ? root.bluetooth.devices : []

        delegate: Column {
          id: bluetoothRow
          required property var modelData
          required property int index
          width: parent.width
          spacing: ShellStyle.Metrics.rowGap

          readonly property bool selected: root.bluetoothFocusSection === "device"
            && root.bluetoothSelectedId === String(modelData.id || "")
          readonly property bool forgetAvailable: modelData.section !== "available"
          readonly property string meta: root.bluetoothRowMeta(modelData)
          readonly property bool startsSection: index === 0
            || String(root.bluetooth.devices[index - 1].section || "") !== String(modelData.section || "")

          Ui.PanelSectionHeader {
            visible: bluetoothRow.startsSection
            label: root.bluetoothSectionLabel(bluetoothRow.modelData.section)
          }

          Row {
            width: parent.width
            spacing: 6

            Item {
              id: bluetoothMain
              width: parent.width - (forgetBluetooth.visible ? forgetBluetooth.width + parent.spacing : 0)
              implicitHeight: ShellStyle.Metrics.controlHeight
              opacity: root.bluetooth && root.bluetooth.actionsEnabled && !root.bluetooth.pending ? 1 : 0.72

              Rectangle {
                anchors.fill: parent
                radius: ShellStyle.Metrics.cornerRadius
                color: bluetoothRow.modelData.connected
                  ? ShellStyle.Palette.selectedWash
                  : ((bluetoothPointer.hovered || (bluetoothRow.selected && !root.bluetoothForgetFocused))
                    ? ShellStyle.Palette.hoverWash
                    : ShellStyle.Palette.normalWash)
                border.width: bluetoothRow.modelData.connected ? 0 : 1
                border.color: (bluetoothPointer.hovered || (bluetoothRow.selected && !root.bluetoothForgetFocused))
                  ? ShellStyle.Palette.hoverBorder
                  : ShellStyle.Palette.controlBorder
              }

              Text {
                id: bluetoothGlyph
                anchors.left: parent.left
                anchors.leftMargin: ShellStyle.Metrics.controlPaddingX
                anchors.verticalCenter: parent.verticalCenter
                text: bluetoothRow.modelData.connected
                  ? String.fromCodePoint(0xF00B1)
                  : String.fromCodePoint(0xF00AF)
                textFormat: Text.PlainText
                color: ShellStyle.Palette.foreground
                font.family: ShellStyle.Metrics.fontFamily
                font.pixelSize: ShellStyle.Metrics.titleSize
              }

              Text {
                anchors.left: bluetoothGlyph.right
                anchors.right: bluetoothMeta.left
                anchors.leftMargin: ShellStyle.Metrics.labelGap
                anchors.rightMargin: ShellStyle.Metrics.labelGap
                anchors.verticalCenter: parent.verticalCenter
                text: String(bluetoothRow.modelData.name || "Bluetooth device")
                textFormat: Text.PlainText
                color: ShellStyle.Palette.foreground
                elide: Text.ElideRight
                font.family: ShellStyle.Metrics.fontFamily
                font.pixelSize: ShellStyle.Metrics.bodySmallSize
                font.weight: Font.Medium
              }

              Text {
                id: bluetoothMeta
                anchors.right: parent.right
                anchors.rightMargin: ShellStyle.Metrics.controlPaddingX
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(132, implicitWidth)
                text: bluetoothRow.meta
                textFormat: Text.PlainText
                color: root.bluetooth && root.bluetooth.errorDeviceId === String(bluetoothRow.modelData.id || "")
                  ? ShellStyle.Palette.urgent
                  : ShellStyle.Palette.muted
                font.family: ShellStyle.Metrics.fontFamily
                font.pixelSize: ShellStyle.Metrics.captionSize
                font.bold: true
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignRight
              }

              HoverHandler {
                id: bluetoothPointer
                onHoveredChanged: if (hovered) {
                  root.cursorActive = true
                  root.bluetoothFocusSection = "device"
                  root.bluetoothSelectedId = String(bluetoothRow.modelData.id || "")
                  root.bluetoothForgetFocused = false
                }
              }
              TapHandler {
                enabled: root.bluetooth && root.bluetooth.actionsEnabled && !root.bluetooth.pending
                acceptedButtons: Qt.LeftButton
                onTapped: root.bluetooth.activateDevice(bluetoothRow.modelData.id)
              }
            }

            Ui.PanelButton {
              id: forgetBluetooth
              visible: bluetoothRow.forgetAvailable
              width: ShellStyle.Metrics.controlHeight
              iconText: String.fromCodePoint(0xF0A7A)
              hasCursor: root.cursorActive && bluetoothRow.selected && root.bluetoothForgetFocused
              enabled: root.bluetooth && root.bluetooth.actionsEnabled && !root.bluetooth.pending
              onHovered: function(value) {
                if (value) {
                  root.cursorActive = true
                  root.bluetoothFocusSection = "device"
                  root.bluetoothSelectedId = String(bluetoothRow.modelData.id || "")
                  root.bluetoothForgetFocused = true
                }
              }
              onClicked: if (root.bluetooth) root.bluetooth.forgetDevice(bluetoothRow.modelData.id)
            }
          }

          onSelectedChanged: if (selected) root.ensureAudioCursorVisible(bluetoothRow)
        }
      }

      Text {
        visible: root.bluetooth && root.bluetooth.available && root.bluetooth.devices.length === 0
        width: parent.width
        text: !root.bluetooth.powered
          ? "Turn Bluetooth on to view nearby devices"
          : (root.bluetooth.discovering
            ? "Scanning for devices…"
            : (root.bluetooth.actionsEnabled
              ? "No devices found · scan again"
              : "No known devices · unlock controls to scan"))
        textFormat: Text.PlainText
        color: ShellStyle.Palette.muted
        font.family: ShellStyle.Metrics.fontFamily
        font.pixelSize: ShellStyle.Metrics.bodySmallSize
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
      }
    }

    Column {
      visible: root.activeControl === "power"
      width: parent.width
      spacing: ShellStyle.Metrics.rowGap

      Ui.PanelSectionHeader { label: "Power profile" }
      Row {
        width: parent.width
        spacing: 6
        readonly property real cellWidth: root.powerProfileChoices.length > 0
          ? (width - spacing * (root.powerProfileChoices.length - 1)) / root.powerProfileChoices.length
          : width

        Repeater {
          model: root.powerProfileChoices
          delegate: Ui.PanelButton {
            required property var modelData
            required property int index
            width: parent.cellWidth
            text: String(modelData.label)
            current: root.power && root.power.profile === String(modelData.token)
            hasCursor: root.cursorActive && root.cursorIndex === index
            enabled: root.power && root.power.actionsEnabled
            onHovered: function(value) {
              if (value) {
                root.cursorActive = true
                root.cursorIndex = index
              }
            }
            onClicked: if (root.power) root.power.setProfile(String(modelData.token))
          }
        }
      }
    }

    Column {
      visible: root.activeControl === "brightness"
      width: parent.width
      spacing: ShellStyle.Metrics.rowGap

      Item {
        width: parent.width
        implicitHeight: Math.max(brightnessHeader.implicitHeight, brightnessPercent.implicitHeight)
        Ui.PanelSectionHeader { id: brightnessHeader; label: "Brightness"; anchors.left: parent.left }
        Text {
          id: brightnessPercent
          textFormat: Text.PlainText
          anchors.right: parent.right
          text: root.brightness && root.brightness.available ? root.brightness.percentage + "%" : "—"
          color: ShellStyle.Palette.muted
          font.family: ShellStyle.Metrics.fontFamily
          font.pixelSize: ShellStyle.Metrics.captionSize
          font.bold: true
        }
      }

      Ui.PanelSlider {
        width: parent.width
        minimum: 1
        value: root.brightness ? root.brightness.percentage : 0
        enabled: root.brightness && root.brightness.available && root.brightness.actionsEnabled
        hasCursor: root.cursorActive
        onCommitted: function(value) { if (root.brightness) root.brightness.setPercentage(value) }
      }
    }

    Text {
      visible: root.activeService && !root.activeService.actionsEnabled
      textFormat: Text.PlainText
      width: parent.width
      text: "CONTROLS LOCKED · READ-ONLY MODE"
      color: ShellStyle.Palette.muted
      font.family: ShellStyle.Metrics.fontFamily
      font.pixelSize: ShellStyle.Metrics.captionSize
      font.bold: true
      font.letterSpacing: 1.2
      horizontalAlignment: Text.AlignHCenter
    }

    Text {
      visible: root.activeService && root.activeService.error !== ""
      textFormat: Text.PlainText
      width: parent.width
      text: root.activeService ? root.activeService.error : ""
      color: ShellStyle.Palette.urgent
      font.family: ShellStyle.Metrics.fontFamily
      font.pixelSize: ShellStyle.Metrics.bodySmallSize
      wrapMode: Text.WordWrap
    }
    }
  }
}
