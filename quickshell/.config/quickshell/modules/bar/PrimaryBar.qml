import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../ui" as Ui
import "../../style" as ShellStyle
import "../controls" as Controls

Ui.X11Panel {
  id: root

  required property QtObject shellState
  required property QtObject bridge
  property var mediaService: null
  property var notificationService: null
  property var dbusOwnershipService: null
  property var tailscaleService: null
  property var clipboardService: null
  property var weatherService: null
  property var audioService: null
  property var networkService: null
  property var bluetoothService: null
  property var powerService: null
  property var brightnessService: null
  property var modalController: null
  property var barPopoutController: null

  readonly property int surfaceCount: 1
  readonly property string resolvedOutputId: bridge ? String(bridge.primaryOutput || "") : ""
  readonly property string resolvedOutputName: outputNameForId(resolvedOutputId)
  readonly property var resolvedScreen: screenForName(resolvedOutputName)
  readonly property string focusedOutputId: bridge ? String(bridge.focusedOutput || resolvedOutputId) : ""
  readonly property string focusedOutputName: outputNameForId(focusedOutputId)
  readonly property var focusedScreen: screenForName(focusedOutputName) || resolvedScreen
  readonly property var controlPopupScreen: resolvedScreen
  readonly property alias visibilityController: visibility
  readonly property alias tagCount: tags.count
  readonly property alias focusedTitle: focusedTitle.title
  readonly property alias clockText: clock.text
  readonly property alias mediaWidget: mediaWidget
  readonly property alias notificationWidget: notificationWidget
  readonly property alias tailscaleWidget: tailscaleWidget
  readonly property alias weatherWidget: weatherWidget
  readonly property alias systemTray: systemTray
  readonly property alias systemControls: systemControls

  signal calendarRequested()


  function outputNameForId(outputId) {
    var outputs = bridge && Array.isArray(bridge.outputs) ? bridge.outputs : []
    for (var i = 0; i < outputs.length; i++) {
      if (String(outputs[i].id || "") === String(outputId || ""))
        return String(outputs[i].name || "")
    }
    return ""
  }

  function screenForName(name) {
    if (!name) return null
    var screens = Quickshell.screens
    for (var i = 0; i < screens.length; i++) {
      if (String(screens[i].name || "") === String(name)) return screens[i]
    }
    return null
  }

  panelSize: ShellStyle.Metrics.barHeight
  reserveSpace: true
  screen: resolvedScreen
  visible: visibility.visible && resolvedScreen !== null
  color: ShellStyle.Palette.barBackground
  surfaceFormat.opaque: false

  BarVisibility {
    id: visibility
    shellState: root.shellState
  }

  Item {
    anchors.fill: parent
    anchors.leftMargin: ShellStyle.Metrics.edgeInset
    anchors.rightMargin: ShellStyle.Metrics.edgeInset

    RowLayout {
      id: leftSection
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      spacing: ShellStyle.Metrics.sectionGap

      Tags {
        id: tags
        tags: root.bridge && Array.isArray(root.bridge.tags) ? root.bridge.tags : []
        onFocusRequested: function(name) {
          if (root.bridge && typeof root.bridge.focusTag === "function") root.bridge.focusTag(name)
        }
      }

      FocusedTitle {
        id: focusedTitle
        Layout.maximumWidth: 320
        title: root.bridge && root.bridge.focusedClient
          ? String(root.bridge.focusedClient.title || root.bridge.focusedClient.class || "")
          : ""
      }
    }

    Clock {
      id: clock
      anchors.centerIn: parent
      onActivated: root.calendarRequested()
    }

    RowLayout {
      id: rightSection
      objectName: "bar-right-section"
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      spacing: ShellStyle.Metrics.controlGap

      WeatherWidget {
        id: weatherWidget
        screen: root.controlPopupScreen
        weatherService: root.weatherService
        barPopoutController: root.barPopoutController
      }

      TailscaleWidget {
        id: tailscaleWidget
        screen: root.controlPopupScreen
        tailscaleService: root.tailscaleService
        clipboardService: root.clipboardService
        barPopoutController: root.barPopoutController
      }

      NotificationWidget {
        id: notificationWidget
        screen: root.controlPopupScreen
        notificationService: root.notificationService
        dbusOwnershipService: root.dbusOwnershipService
        barPopoutController: root.barPopoutController
      }

      MediaWidget {
        id: mediaWidget
        screen: root.controlPopupScreen
        mediaService: root.mediaService
        barPopoutController: root.barPopoutController
      }

      SystemTray {
        id: systemTray
        screen: root.controlPopupScreen
        barPopoutController: root.barPopoutController
      }

      Controls.SystemControls {
        id: systemControls
        screen: root.controlPopupScreen
        audio: root.audioService
        network: root.networkService
        bluetooth: root.bluetoothService
        power: root.powerService
        brightness: root.brightnessService
        modalController: root.modalController
        barPopoutController: root.barPopoutController
        visible: root.audioService !== null
          && root.networkService !== null
          && root.bluetoothService !== null
          && root.powerService !== null
          && root.brightnessService !== null
      }
    }
  }
}
