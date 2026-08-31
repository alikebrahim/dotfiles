import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../style" as ShellStyle
import "../../ui" as Ui

Item {
  id: root

  required property QtObject bridge
  required property QtObject sessionActions
  required property QtObject modalController

  readonly property string surfaceName: "session-menu"
  readonly property var targetScreen: resolveTargetScreen()
  readonly property var actions: [
    { id: "suspend", label: "Suspend", detail: "Pause this session" },
    { id: "logout", label: "Logout", detail: "End the Awesome session" },
    { id: "restart", label: "Restart", detail: "Restart this computer" },
    { id: "poweroff", label: "Power off", detail: "Shut down this computer" }
  ]

  property bool open: false
  property int selectedIndex: 0
  property real cardOpacity: open ? 1 : 0

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

  function selectedAction() {
    return actions[Math.max(0, Math.min(selectedIndex, actions.length - 1))]
  }

  function focusKeyboardItem() {
    if (root.open) keyboardCapture.forceActiveFocus(Qt.ShortcutFocusReason)
  }

  function requestKeyboardFocus() {
    if (!root.open) return
    var windowObject = sessionWindow.contentItem
      ? sessionWindow.contentItem.Window.window
      : null
    if (!windowObject) return
    if (windowObject.active) root.focusKeyboardItem()
    else windowObject.requestActivate()
  }

  function openMenu() {
    if (!targetScreen) return false
    modalController.activate(surfaceName)
    sessionActions.cancelConfirmation()
    selectedIndex = 0
    open = true
    focusRetry.begin()
    return true
  }

  function closeMenu() {
    if (sessionActions.busy) return false
    open = false
    focusRetry.stop()
    sessionActions.cancelConfirmation()
    modalController.release(surfaceName)
    return true
  }

  function toggleMenu() {
    return open ? closeMenu() : openMenu()
  }

  function moveSelection(delta) {
    if (sessionActions.busy) return
    sessionActions.cancelConfirmation()
    selectedIndex = (selectedIndex + delta + actions.length) % actions.length
  }

  function activateSelection() {
    if (sessionActions.busy) return false
    var action = selectedAction()
    if (!action) return false

    if (sessionActions.armedAction !== action.id)
      return sessionActions.arm(action.id)

    return sessionActions.executeConfirmed(action.id)
  }

  function cancelOrClose() {
    if (sessionActions.armedAction !== "") sessionActions.cancelConfirmation()
    else closeMenu()
  }

  Connections {
    target: root.modalController
    function onCloseRequested(surface) {
      if (surface === root.surfaceName) root.closeMenu()
    }
  }

  Connections {
    target: root.sessionActions

    function onActionAccepted(action) {
      if (root.open) root.closeMenu()
    }
  }

  Ui.WindowFocusRetry {
    id: focusRetry
    panel: sessionWindow
    onSucceeded: root.focusKeyboardItem()
  }

  Connections {
    id: sessionActivation
    target: sessionWindow.contentItem ? sessionWindow.contentItem.Window.window : null

    function onActiveChanged() {
      var windowObject = sessionActivation.target
      if (!root.open || !windowObject) return
      root.modalController.reportWindowActive(root.surfaceName, windowObject.active)
      if (windowObject.active) Qt.callLater(root.focusKeyboardItem)
    }
  }

  PanelWindow {
    id: sessionWindow

    screen: root.targetScreen
    visible: root.open || root.cardOpacity > 0
    focusable: root.open
    aboveWindows: true
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    color: "transparent"
    surfaceFormat.opaque: false
    implicitWidth: 420
    implicitHeight: 310

    onVisibleChanged: if (visible && root.open) focusRetry.begin()

    Binding {
      target: sessionWindow.contentItem ? sessionWindow.contentItem.Window.window : null
      property: "title"
      value: "quickshell-session-menu"
      when: target !== null
      restoreMode: Binding.RestoreBindingOrValue
    }

    FocusScope {
      id: keyboardCapture
      anchors.fill: parent
      focus: root.open

      Keys.priority: Keys.BeforeItem
      Keys.onPressed: function(event) {
        var control = event.modifiers & Qt.ControlModifier
        if (event.key === Qt.Key_Escape) {
          root.cancelOrClose()
          event.accepted = true
        } else if (event.key === Qt.Key_Down || (control && event.key === Qt.Key_N)) {
          root.moveSelection(1)
          event.accepted = true
        } else if (event.key === Qt.Key_Up || (control && event.key === Qt.Key_P)) {
          root.moveSelection(-1)
          event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
          root.activateSelection()
          event.accepted = true
        }
      }

      Rectangle {
        anchors.fill: parent
        opacity: root.cardOpacity
        color: ShellStyle.Palette.panel
        border.width: 2
        border.color: ShellStyle.Palette.panelBorder
        radius: ShellStyle.Metrics.cornerRadius

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: ShellStyle.Metrics.panelPadding
          spacing: ShellStyle.Metrics.rowGap

          RowLayout {
            Layout.fillWidth: true

            Text {
              text: root.sessionActions.armedAction === "" ? "SESSION" : "CONFIRM ACTION"
              textFormat: Text.PlainText
              color: root.sessionActions.armedAction === ""
                ? ShellStyle.Palette.accent
                : ShellStyle.Palette.urgent
              font.family: ShellStyle.Metrics.fontFamily
              font.pixelSize: ShellStyle.Metrics.titleSize
              font.weight: Font.DemiBold
            }

            Item { Layout.fillWidth: true }

            Text {
              text: "Mod+Esc"
              textFormat: Text.PlainText
              color: ShellStyle.Palette.muted
              font.family: ShellStyle.Metrics.fontFamily
              font.pixelSize: ShellStyle.Metrics.captionSize
            }
          }

          Text {
            Layout.fillWidth: true
            text: root.sessionActions.armedAction === ""
              ? "Choose a session action"
              : "Press Enter again to " + root.sessionActions.actionLabel(root.sessionActions.armedAction).toLowerCase()
            textFormat: Text.PlainText
            color: root.sessionActions.armedAction === ""
              ? ShellStyle.Palette.muted
              : ShellStyle.Palette.foreground
            font.family: ShellStyle.Metrics.fontFamily
            font.pixelSize: ShellStyle.Metrics.bodySmallSize
            wrapMode: Text.Wrap
          }

          ListView {
            id: actionList
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 4
            interactive: false
            model: root.actions
            currentIndex: root.selectedIndex

            delegate: Rectangle {
              id: actionRow
              required property var modelData
              required property int index

              readonly property bool selected: index === root.selectedIndex
              readonly property bool armed: root.sessionActions.armedAction === modelData.id

              width: ListView.view.width
              height: 44
              radius: ShellStyle.Metrics.cornerRadius
              color: selected ? ShellStyle.Palette.selectedWash
                : rowPointer.containsMouse ? ShellStyle.Palette.hoverWash : ShellStyle.Palette.normalWash
              border.width: armed ? 1 : 0
              border.color: ShellStyle.Palette.urgent

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: ShellStyle.Metrics.controlPaddingX
                anchors.rightMargin: ShellStyle.Metrics.controlPaddingX
                spacing: ShellStyle.Metrics.labelGap

                Text {
                  Layout.preferredWidth: 90
                  text: actionRow.modelData.label
                  textFormat: Text.PlainText
                  color: actionRow.armed ? ShellStyle.Palette.urgent : ShellStyle.Palette.foreground
                  font.family: ShellStyle.Metrics.fontFamily
                  font.pixelSize: ShellStyle.Metrics.bodySize
                  font.weight: Font.Medium
                }

                Text {
                  Layout.fillWidth: true
                  text: actionRow.armed ? "Confirm this action" : actionRow.modelData.detail
                  textFormat: Text.PlainText
                  color: ShellStyle.Palette.muted
                  font.family: ShellStyle.Metrics.fontFamily
                  font.pixelSize: ShellStyle.Metrics.captionSize
                  elide: Text.ElideRight
                }
              }

              MouseArea {
                id: rowPointer
                anchors.fill: parent
                hoverEnabled: true
                onEntered: {
                  if (root.sessionActions.armedAction === "") root.selectedIndex = actionRow.index
                }
                onClicked: {
                  if (root.selectedIndex !== actionRow.index) {
                    root.sessionActions.cancelConfirmation()
                    root.selectedIndex = actionRow.index
                  }
                  root.activateSelection()
                }
              }
            }
          }

          Text {
            Layout.fillWidth: true
            visible: root.sessionActions.error.length > 0
            text: root.sessionActions.error
            textFormat: Text.PlainText
            color: ShellStyle.Palette.urgent
            font.family: ShellStyle.Metrics.fontFamily
            font.pixelSize: ShellStyle.Metrics.bodySmallSize
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
          }

          Text {
            Layout.fillWidth: true
            text: root.sessionActions.armedAction === ""
              ? "↑ / Ctrl+P  ·  ↓ / Ctrl+N  ·  Enter select  ·  Esc close"
              : "Enter confirm  ·  Esc cancel"
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

  IpcHandler {
    target: "sessionMenu"

    function toggleMenu(): string {
      return root.toggleMenu() ? (root.open ? "open" : "closed") : "unavailable"
    }

    function openMenu(): string {
      return root.openMenu() ? "open" : "unavailable"
    }

    function closeMenu(): string {
      root.closeMenu()
      return "closed"
    }

    function status(): string {
      return JSON.stringify({
        open: root.open,
        selected: root.selectedAction() ? root.selectedAction().id : "",
        armed: root.sessionActions.armedAction,
        focused: keyboardCapture.activeFocus,
        error: root.sessionActions.error
      })
    }
  }
}
