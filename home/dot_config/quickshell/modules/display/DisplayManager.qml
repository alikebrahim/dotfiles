import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../style" as ShellStyle
import "../../ui" as Ui

Item {
  id: root

  required property QtObject bridge
  required property QtObject displayService
  required property QtObject modalController

  readonly property string surfaceName: "display-manager"
  readonly property var targetScreen: resolveTargetScreen()
  readonly property var profiles: displayService ? displayService.profiles : []
  readonly property var selectedProfile: {
    if (profiles.length === 0) return null
    return profiles[Math.max(0, Math.min(selectedIndex, profiles.length - 1))]
  }

  property bool open: false
  property int selectedIndex: 0
  property int failedProfileIndex: 0
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

  function indexForProfile(profileId) {
    var requested = String(profileId || "")
    for (var i = 0; i < profiles.length; i++)
      if (profiles[i].id === requested) return i
    return 0
  }

  function focusKeyboardItem() {
    if (root.open) keyboardCapture.forceActiveFocus(Qt.ShortcutFocusReason)
  }

  function requestKeyboardFocus() {
    if (!root.open) return
    var windowObject = displayWindow.contentItem
      ? displayWindow.contentItem.Window.window
      : null
    if (!windowObject) return
    if (windowObject.active) root.focusKeyboardItem()
    else windowObject.requestActivate()
  }

  function openManager() {
    if (!targetScreen || profiles.length === 0 || !displayService.actionsEnabled) return false
    modalController.activate(surfaceName)
    displayService.cancelConfirmation()
    displayService.clearError()
    displayService.refreshCurrent()
    selectedIndex = indexForProfile(displayService.currentProfile)
    open = true
    focusRetry.begin()
    return true
  }

  function reopenAfterFailure() {
    if (!targetScreen || profiles.length === 0) return false
    modalController.activate(surfaceName)
    displayService.cancelConfirmation()
    selectedIndex = Math.max(0, Math.min(failedProfileIndex, profiles.length - 1))
    open = true
    focusRetry.begin()
    return true
  }

  function closeManager() {
    open = false
    focusRetry.stop()
    displayService.cancelConfirmation()
    modalController.release(surfaceName)
    return true
  }

  function toggleManager() {
    return open ? closeManager() : openManager()
  }

  function moveSelection(delta) {
    if (displayService.busy || profiles.length === 0) return
    displayService.cancelConfirmation()
    displayService.clearError()
    selectedIndex = (selectedIndex + delta + profiles.length) % profiles.length
    optionList.positionViewAtIndex(selectedIndex, ListView.Contain)
  }

  function activateSelection() {
    if (displayService.busy || !selectedProfile) return false

    if (displayService.armedProfile !== selectedProfile.id)
      return displayService.arm(selectedProfile.id)

    failedProfileIndex = selectedIndex
    if (!displayService.applyConfirmed(selectedProfile.id)) return false

    // RandR may disable the output hosting this surface. Release focus and
    // unmap before the mutation reaches the command runner.
    closeManager()
    return true
  }

  function cancelOrClose() {
    if (displayService.armedProfile !== "") displayService.cancelConfirmation()
    else closeManager()
  }

  onTargetScreenChanged: {
    if (open && !targetScreen) closeManager()
  }

  Connections {
    target: root.modalController
    function onCloseRequested(surface) {
      if (surface === root.surfaceName) root.closeManager()
    }
  }

  Connections {
    target: root.displayService
    function onActionFinished(profile, ok, message) {
      if (!ok) failureReopen.restart()
    }
  }

  Ui.WindowFocusRetry {
    id: focusRetry
    panel: displayWindow
    onSucceeded: root.focusKeyboardItem()
  }

  Connections {
    target: root.displayService
    function onCurrentProfileChanged() {
      if (!root.open || root.displayService.armedProfile !== "") return
      root.selectedIndex = root.indexForProfile(root.displayService.currentProfile)
    }
  }

  Timer {
    id: failureReopen
    interval: 280
    repeat: false
    onTriggered: root.reopenAfterFailure()
  }

  Connections {
    id: displayActivation
    target: displayWindow.contentItem ? displayWindow.contentItem.Window.window : null

    function onActiveChanged() {
      var windowObject = displayActivation.target
      if (!root.open || !windowObject) return
      root.modalController.reportWindowActive(root.surfaceName, windowObject.active)
      if (windowObject.active) Qt.callLater(root.focusKeyboardItem)
    }
  }

  PanelWindow {
    id: displayWindow

    screen: root.targetScreen
    visible: root.open || root.cardOpacity > 0
    focusable: root.open
    aboveWindows: true
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    color: "transparent"
    surfaceFormat.opaque: false
    implicitWidth: 570
    implicitHeight: 490

    onVisibleChanged: if (visible && root.open) focusRetry.begin()

    Binding {
      target: displayWindow.contentItem ? displayWindow.contentItem.Window.window : null
      property: "title"
      value: "quickshell-display-manager"
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
              text: root.displayService.armedProfile === ""
                ? "DISPLAY PROFILE"
                : "CONFIRM DISPLAY CHANGE"
              textFormat: Text.PlainText
              color: root.displayService.armedProfile === ""
                ? ShellStyle.Palette.accent
                : ShellStyle.Palette.urgent
              font.family: ShellStyle.Metrics.fontFamily
              font.pixelSize: ShellStyle.Metrics.titleSize
              font.weight: Font.DemiBold
            }

            Item { Layout.fillWidth: true }

            Text {
              text: "Mod+P"
              textFormat: Text.PlainText
              color: ShellStyle.Palette.muted
              font.family: ShellStyle.Metrics.fontFamily
              font.pixelSize: ShellStyle.Metrics.captionSize
            }
          }

          Text {
            Layout.fillWidth: true
            text: root.displayService.error !== ""
              ? root.displayService.error
              : root.displayService.armedProfile === ""
                ? "Select a fixed monitor layout"
                : "Press Enter again to apply " + root.displayService.profileLabel(root.displayService.armedProfile)
            textFormat: Text.PlainText
            color: root.displayService.error !== ""
              ? ShellStyle.Palette.urgent
              : root.displayService.armedProfile === ""
                ? ShellStyle.Palette.muted
                : ShellStyle.Palette.foreground
            font.family: ShellStyle.Metrics.fontFamily
            font.pixelSize: ShellStyle.Metrics.bodySmallSize
            elide: Text.ElideRight
          }

          ListView {
            id: optionList
            Layout.fillWidth: true
            Layout.preferredHeight: 220
            spacing: 4
            interactive: false
            clip: true
            model: root.profiles
            currentIndex: root.selectedIndex

            delegate: Rectangle {
              id: profileRow
              required property var modelData
              required property int index

              readonly property bool selected: index === root.selectedIndex
              readonly property bool armed: root.displayService.armedProfile === modelData.id

              width: ListView.view.width
              height: 52
              radius: ShellStyle.Metrics.cornerRadius
              color: selected
                ? ShellStyle.Palette.selectedWash
                : rowPointer.containsMouse ? ShellStyle.Palette.hoverWash : ShellStyle.Palette.normalWash
              border.width: armed ? 1 : 0
              border.color: ShellStyle.Palette.urgent

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: ShellStyle.Metrics.controlPaddingX
                anchors.rightMargin: ShellStyle.Metrics.controlPaddingX
                spacing: ShellStyle.Metrics.labelGap

                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: 1

                  Text {
                    Layout.fillWidth: true
                    text: modelData.label
                    textFormat: Text.PlainText
                    color: ShellStyle.Palette.foreground
                    font.family: ShellStyle.Metrics.fontFamily
                    font.pixelSize: ShellStyle.Metrics.bodySize
                    font.weight: selected ? Font.DemiBold : Font.Normal
                  }

                  Text {
                    Layout.fillWidth: true
                    text: modelData.detail
                    textFormat: Text.PlainText
                    color: ShellStyle.Palette.muted
                    font.family: ShellStyle.Metrics.fontFamily
                    font.pixelSize: ShellStyle.Metrics.captionSize
                    elide: Text.ElideRight
                  }
                }

                Text {
                  text: armed ? "ARMED" : selected ? "ENTER" : ""
                  textFormat: Text.PlainText
                  color: armed ? ShellStyle.Palette.urgent : ShellStyle.Palette.muted
                  font.family: ShellStyle.Metrics.fontFamily
                  font.pixelSize: ShellStyle.Metrics.captionSize
                  font.weight: Font.DemiBold
                }
              }

              MouseArea {
                id: rowPointer
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.selectedIndex = profileRow.index
                  root.activateSelection()
                }
              }
            }
          }

          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 82
            color: ShellStyle.Palette.normalWash
            radius: ShellStyle.Metrics.cornerRadius

            ColumnLayout {
              anchors.fill: parent
              anchors.margins: ShellStyle.Metrics.controlPaddingX
              spacing: 3

              Text {
                Layout.fillWidth: true
                text: root.selectedProfile ? root.selectedProfile.label.toUpperCase() : ""
                textFormat: Text.PlainText
                color: ShellStyle.Palette.accent
                font.family: ShellStyle.Metrics.fontFamily
                font.pixelSize: ShellStyle.Metrics.captionSize
                font.weight: Font.DemiBold
              }

              Repeater {
                model: root.selectedProfile ? root.selectedProfile.lines : []

                Text {
                  required property var modelData
                  Layout.fillWidth: true
                  text: String(modelData || "")
                  textFormat: Text.PlainText
                  color: ShellStyle.Palette.foreground
                  font.family: ShellStyle.Metrics.fontFamily
                  font.pixelSize: ShellStyle.Metrics.bodySmallSize
                  elide: Text.ElideRight
                }
              }
            }
          }

          Text {
            Layout.fillWidth: true
            text: "Up / Down choose  ·  Enter arm / apply  ·  Esc cancel / close"
            textFormat: Text.PlainText
            horizontalAlignment: Text.AlignHCenter
            color: ShellStyle.Palette.muted
            font.family: ShellStyle.Metrics.fontFamily
            font.pixelSize: ShellStyle.Metrics.captionSize
          }
        }
      }
    }
  }

  IpcHandler {
    target: "displayManager"

    function openManager(): string {
      if (root.displayService.busy) return "busy"
      if (!root.displayService.actionsEnabled) return "disabled"
      return root.openManager() ? "open" : "unavailable"
    }

    function closeManager(): string {
      root.closeManager()
      return "closed"
    }

    function toggleManager(): string {
      if (root.displayService.busy) return "busy"
      if (!root.displayService.actionsEnabled) return "disabled"
      return root.toggleManager() ? (root.open ? "open" : "closed") : "unavailable"
    }

    function status(): string {
      var windowObject = displayWindow.contentItem
        ? displayWindow.contentItem.Window.window
        : null
      return JSON.stringify({
        open: root.open,
        focused: root.open && windowObject ? windowObject.active : false,
        enabled: root.displayService.actionsEnabled,
        busy: root.displayService.busy,
        armed: root.displayService.armedProfile,
        selected: root.selectedProfile ? root.selectedProfile.id : "",
        lastApplied: root.displayService.lastAppliedProfile,
        error: root.displayService.error,
        screen: root.targetScreen ? root.targetScreen.name : ""
      })
    }
  }
}
