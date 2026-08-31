import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../style" as ShellStyle
import "../../ui" as Ui

Item {
  id: root

  required property QtObject bridge
  required property QtObject actions
  required property QtObject modalController

  property bool open: false
  property int selectedIndex: 0
  property int pendingWindowId: 0
  property string error: ""
  property real cardOpacity: open ? 1 : 0
  readonly property string surfaceName: "window-switcher"
  readonly property var clients: bridge && Array.isArray(bridge.clients) ? bridge.clients : []
  readonly property var targetScreen: resolveTargetScreen()
  readonly property var filteredClients: filterClients(searchInput.text)

  Behavior on cardOpacity {
    enabled: !root.modalController.dismissImmediately
    NumberAnimation {
      duration: ShellStyle.Metrics.animationMs
      easing.type: Easing.OutCubic
    }
  }

  function resolveTargetScreen() {
    var names = []
    if (bridge) {
      var focused = String(bridge.focusedOutput || "")
      var primary = String(bridge.primaryOutput || "")
      if (focused) names.push(focused)
      if (primary && names.indexOf(primary) === -1) names.push(primary)
    }
    for (var nameIndex = 0; nameIndex < names.length; nameIndex++) {
      for (var screenIndex = 0; screenIndex < Quickshell.screens.length; screenIndex++) {
        var candidate = Quickshell.screens[screenIndex]
        if (candidate && String(candidate.name || "") === names[nameIndex]) return candidate
      }
    }
    for (var fallbackIndex = 0; fallbackIndex < Quickshell.screens.length; fallbackIndex++)
      if (Quickshell.screens[fallbackIndex]) return Quickshell.screens[fallbackIndex]
    return null
  }

  function searchableText(entry) {
    return [
      entry.title,
      entry.class,
      entry.output,
      entry.side,
      entry.tagIndex > 0 ? String(entry.tagIndex) : "S"
    ].join(" ").toLowerCase()
  }

  function filterClients(query) {
    var source = clients
    var needle = String(query || "").trim().toLowerCase()
    if (!needle) return source.slice()
    var matches = []
    for (var i = 0; i < source.length; i++)
      if (searchableText(source[i]).indexOf(needle) !== -1) matches.push(source[i])
    return matches
  }

  function clampSelection() {
    var count = filteredClients.length
    if (count === 0) selectedIndex = 0
    else selectedIndex = Math.max(0, Math.min(selectedIndex, count - 1))
    if (count > 0) windowList.positionViewAtIndex(selectedIndex, ListView.Contain)
  }

  function moveSelection(delta) {
    var count = filteredClients.length
    if (count === 0 || pendingWindowId !== 0) return
    selectedIndex = (selectedIndex + delta + count) % count
    windowList.positionViewAtIndex(selectedIndex, ListView.Contain)
  }

  function focusKeyboardItem() {
    if (root.open) searchInput.forceActiveFocus(Qt.ShortcutFocusReason)
  }

  function requestKeyboardFocus() {
    if (!root.open) return
    var windowObject = switcherWindow.contentItem
      ? switcherWindow.contentItem.Window.window
      : null
    if (!windowObject) return
    if (windowObject.active) root.focusKeyboardItem()
    else windowObject.requestActivate()
  }

  function openSwitcher() {
    if (targetScreen === null) return false
    modalController.activate(surfaceName)
    error = ""
    pendingWindowId = 0
    searchInput.text = ""
    selectedIndex = 0
    open = true
    focusRetry.begin()
    Qt.callLater(function() {
      root.clampSelection()
    })
    return true
  }

  function closeSwitcher() {
    open = false
    pendingWindowId = 0
    error = ""
    focusRetry.stop()
    modalController.release(surfaceName)
    return true
  }

  function toggleSwitcher() {
    return open ? closeSwitcher() : openSwitcher()
  }

  function activateSelection() {
    if (pendingWindowId !== 0 || filteredClients.length === 0) return false
    var entry = filteredClients[selectedIndex]
    if (!entry || !actions.activateWindow(entry.id)) {
      error = actions.error || "Window activation was rejected"
      return false
    }
    pendingWindowId = Number(entry.id)
    error = ""
    return true
  }

  onFilteredClientsChanged: Qt.callLater(clampSelection)

  Connections {
    target: root.modalController
    function onCloseRequested(surface) {
      if (surface === root.surfaceName) root.closeSwitcher()
    }
  }

  Connections {
    target: root.actions
    function onWindowActivationFinished(windowId, ok, message) {
      if (Number(windowId) !== root.pendingWindowId) return
      root.pendingWindowId = 0
      if (ok) root.closeSwitcher()
      else root.error = String(message || "Window activation failed")
    }
  }

  Ui.WindowFocusRetry {
    id: focusRetry
    panel: switcherWindow
    onSucceeded: root.focusKeyboardItem()
  }

  Connections {
    id: switcherActivation
    target: switcherWindow.contentItem ? switcherWindow.contentItem.Window.window : null

    function onActiveChanged() {
      var windowObject = switcherActivation.target
      if (!root.open || !windowObject) return
      root.modalController.reportWindowActive(root.surfaceName, windowObject.active)
      if (windowObject.active) Qt.callLater(root.focusKeyboardItem)
    }
  }

  IpcHandler {
    target: "windowSwitcher"

    function openSwitcher(): string {
      return root.openSwitcher() ? "open" : "unavailable"
    }

    function closeSwitcher(): string {
      root.closeSwitcher()
      return "closed"
    }

    function toggleSwitcher(): string {
      return root.toggleSwitcher() ? (root.open ? "open" : "closed") : "unavailable"
    }

    function status(): string {
      return JSON.stringify({
        open: root.open,
        clients: root.filteredClients.length,
        pendingWindowId: root.pendingWindowId,
        focused: searchInput.activeFocus,
        error: root.error
      })
    }
  }

  PanelWindow {
    id: switcherWindow

    screen: root.targetScreen
    visible: root.open || root.cardOpacity > 0
    implicitWidth: 660
    implicitHeight: 430
    color: "transparent"
    surfaceFormat.opaque: false
    focusable: root.open
    aboveWindows: true
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0

    onVisibleChanged: if (visible && root.open) focusRetry.begin()

    Binding {
      target: switcherWindow.contentItem.Window.window
      property: "title"
      value: "quickshell-window-switcher"
      when: switcherWindow.contentItem.Window.window !== null
    }

    Rectangle {
      anchors.fill: parent
      opacity: root.cardOpacity
      radius: ShellStyle.Metrics.cornerRadius
      color: ShellStyle.Palette.panel
      border.width: 2
      border.color: ShellStyle.Palette.panelBorder

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: ShellStyle.Metrics.panelPadding
        spacing: ShellStyle.Metrics.rowGap

        RowLayout {
          Layout.fillWidth: true
          spacing: ShellStyle.Metrics.labelGap

          Text {
            text: "WINDOWS"
            textFormat: Text.PlainText
            color: ShellStyle.Palette.accent
            font.family: ShellStyle.Metrics.fontFamily
            font.pixelSize: ShellStyle.Metrics.titleSize
            font.weight: Font.DemiBold
          }

          Item { Layout.fillWidth: true }

          Text {
            text: root.filteredClients.length + " / " + root.clients.length
            textFormat: Text.PlainText
            color: ShellStyle.Palette.muted
            font.family: ShellStyle.Metrics.fontFamily
            font.pixelSize: ShellStyle.Metrics.captionSize
          }
        }

        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: 34
          radius: ShellStyle.Metrics.cornerRadius
          color: ShellStyle.Palette.normalWash
          border.width: 1
          border.color: searchInput.activeFocus
            ? ShellStyle.Palette.accent
            : ShellStyle.Palette.hoverBorder

          Text {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            visible: searchInput.text.length === 0
            text: "Type to filter windows"
            textFormat: Text.PlainText
            color: ShellStyle.Palette.muted
            font.family: ShellStyle.Metrics.fontFamily
            font.pixelSize: ShellStyle.Metrics.bodySize
          }

          TextInput {
            id: searchInput
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            verticalAlignment: TextInput.AlignVCenter
            color: ShellStyle.Palette.foreground
            selectionColor: ShellStyle.Palette.selectedWash
            selectedTextColor: ShellStyle.Palette.foreground
            font.family: ShellStyle.Metrics.fontFamily
            font.pixelSize: ShellStyle.Metrics.bodySize
            clip: true
            enabled: root.pendingWindowId === 0

            onTextChanged: {
              root.selectedIndex = 0
              Qt.callLater(root.clampSelection)
            }

            Keys.priority: Keys.BeforeItem
            Keys.onPressed: function(event) {
              var control = event.modifiers & Qt.ControlModifier
              if (event.key === Qt.Key_Escape) {
                root.closeSwitcher()
                event.accepted = true
              } else if (event.key === Qt.Key_Down
                         || (control && event.key === Qt.Key_N)) {
                root.moveSelection(1)
                event.accepted = true
              } else if (event.key === Qt.Key_Up
                         || (control && event.key === Qt.Key_P)) {
                root.moveSelection(-1)
                event.accepted = true
              } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.activateSelection()
                event.accepted = true
              }
            }
          }
        }

        ListView {
          id: windowList
          Layout.fillWidth: true
          Layout.fillHeight: true
          clip: true
          spacing: 4
          model: root.filteredClients
          currentIndex: root.selectedIndex

          delegate: Rectangle {
            id: row
            required property var modelData
            required property int index

            width: ListView.view.width
            height: 54
            radius: ShellStyle.Metrics.cornerRadius
            color: index === root.selectedIndex
              ? ShellStyle.Palette.selectedWash
              : rowMouse.containsMouse ? ShellStyle.Palette.hoverWash : "transparent"
            border.width: index === root.selectedIndex ? 1 : 0
            border.color: ShellStyle.Palette.controlBorder

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 10
              anchors.rightMargin: 10
              spacing: 10

              Text {
                Layout.preferredWidth: 62
                text: "[" + (row.modelData.tagIndex > 0 ? row.modelData.tagIndex : "S")
                  + ":" + (row.modelData.side || "C") + "]"
                textFormat: Text.PlainText
                color: ShellStyle.Palette.accent
                font.family: ShellStyle.Metrics.fontFamily
                font.pixelSize: ShellStyle.Metrics.bodySmallSize
                font.weight: Font.DemiBold
              }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                  Layout.fillWidth: true
                  text: row.modelData.title || "(untitled)"
                  textFormat: Text.PlainText
                  elide: Text.ElideRight
                  color: ShellStyle.Palette.foreground
                  font.family: ShellStyle.Metrics.fontFamily
                  font.pixelSize: ShellStyle.Metrics.bodySize
                  font.weight: Font.Medium
                }

                Text {
                  Layout.fillWidth: true
                  text: (row.modelData.class || "unknown") + "  ·  " + (row.modelData.output || "unknown")
                  textFormat: Text.PlainText
                  elide: Text.ElideRight
                  color: ShellStyle.Palette.muted
                  font.family: ShellStyle.Metrics.fontFamily
                  font.pixelSize: ShellStyle.Metrics.captionSize
                }
              }

              Text {
                Layout.preferredWidth: 44
                horizontalAlignment: Text.AlignRight
                text: (row.modelData.minimized ? "H" : "")
                  + (row.modelData.maximized ? "M" : "")
                  + (row.modelData.fullscreen ? "F" : "")
                textFormat: Text.PlainText
                color: row.modelData.urgent ? ShellStyle.Palette.urgent : ShellStyle.Palette.muted
                font.family: ShellStyle.Metrics.fontFamily
                font.pixelSize: ShellStyle.Metrics.bodySmallSize
              }
            }

            MouseArea {
              id: rowMouse
              anchors.fill: parent
              hoverEnabled: true
              onEntered: root.selectedIndex = row.index
              onClicked: {
                root.selectedIndex = row.index
                root.activateSelection()
              }
            }
          }
        }

        Text {
          Layout.fillWidth: true
          visible: root.filteredClients.length === 0 || root.error.length > 0 || root.pendingWindowId !== 0
          text: root.error.length > 0
            ? root.error
            : root.pendingWindowId !== 0 ? "Opening selected window…" : "No matching windows"
          textFormat: Text.PlainText
          color: root.error.length > 0 ? ShellStyle.Palette.urgent : ShellStyle.Palette.muted
          font.family: ShellStyle.Metrics.fontFamily
          font.pixelSize: ShellStyle.Metrics.bodySmallSize
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.Wrap
        }

        Text {
          Layout.fillWidth: true
          text: "↑ / Ctrl+P  ·  ↓ / Ctrl+N  ·  Enter open  ·  Esc close"
          textFormat: Text.PlainText
          color: ShellStyle.Palette.muted
          font.family: ShellStyle.Metrics.fontFamily
          font.pixelSize: ShellStyle.Metrics.captionSize
          horizontalAlignment: Text.AlignHCenter
        }
      }
    }
  }
}
