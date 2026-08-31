import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../style" as ShellStyle
import "../../ui" as Ui

Item {
  id: root

  required property QtObject bridge
  required property QtObject modalController

  readonly property string surfaceName: "keybind-help"
  readonly property var entries: bridge && bridge.keybinds ? bridge.keybinds : []
  readonly property int entryCount: entries.length
  readonly property var filteredEntries: filterEntries(searchInput.text)
  readonly property var targetScreen: resolveTargetScreen()
  readonly property bool focused: {
    var windowObject = helpWindow.contentItem ? helpWindow.contentItem.Window.window : null
    return !!(windowObject && windowObject.active)
  }

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

  function groupRank(group) {
    var order = {
      launcher: 0,
      system: 1,
      client: 2,
      screen: 3,
      tag: 4,
      workspace: 5,
      screenshots: 6,
      layout: 7,
      awesome: 8
    }
    var normalized = String(group || "misc").toLowerCase()
    return order[normalized] === undefined ? 99 : order[normalized]
  }

  function groupLabel(group) {
    var labels = {
      launcher: "LAUNCH",
      system: "SYSTEM CONTROLS",
      client: "WINDOWS",
      screen: "SCREENS",
      tag: "WORKSPACE NAVIGATION",
      workspace: "WORKSPACES",
      screenshots: "SCREENSHOTS",
      layout: "LAYOUT",
      awesome: "AWESOMEWM"
    }
    var normalized = String(group || "misc").toLowerCase()
    return labels[normalized] || normalized.toUpperCase()
  }

  function filterEntries(value) {
    var query = String(value || "").trim().toLowerCase()
    var tokens = query ? query.split(/\s+/) : []
    var result = []

    for (var i = 0; i < entries.length; i++) {
      var entry = entries[i]
      if (!entry) continue
      var combo = String(entry.combo || "")
      var description = String(entry.description || "")
      var group = String(entry.group || "misc").toLowerCase()
      if (!combo || !description) continue

      var haystack = [combo, description, group, groupLabel(group)].join(" ").toLowerCase()
      var matches = true
      for (var tokenIndex = 0; tokenIndex < tokens.length; tokenIndex++) {
        if (haystack.indexOf(tokens[tokenIndex]) === -1) {
          matches = false
          break
        }
      }
      if (matches) result.push({ combo: combo, description: description, group: group })
    }

    result.sort(function(left, right) {
      var rankDifference = groupRank(left.group) - groupRank(right.group)
      if (rankDifference !== 0) return rankDifference
      var comboDifference = left.combo.localeCompare(right.combo)
      return comboDifference !== 0 ? comboDifference : left.description.localeCompare(right.description)
    })
    return result
  }

  function clampSelection() {
    var count = filteredEntries.length
    if (count === 0) selectedIndex = 0
    else selectedIndex = Math.max(0, Math.min(selectedIndex, count - 1))
    bindingList.currentIndex = selectedIndex
  }

  function moveSelection(delta) {
    var count = filteredEntries.length
    if (count === 0) return
    selectedIndex = (selectedIndex + delta + count) % count
    bindingList.currentIndex = selectedIndex
    bindingList.positionViewAtIndex(selectedIndex, ListView.Contain)
  }

  function focusKeyboardItem() {
    if (root.open) searchInput.forceActiveFocus(Qt.ShortcutFocusReason)
  }

  function requestKeyboardFocus() {
    if (!root.open) return
    var windowObject = helpWindow.contentItem ? helpWindow.contentItem.Window.window : null
    if (!windowObject) return
    if (windowObject.active) root.focusKeyboardItem()
    else windowObject.requestActivate()
  }

  function openHelp() {
    if (!targetScreen || entryCount === 0) return false
    modalController.activate(surfaceName)
    searchInput.text = ""
    selectedIndex = 0
    open = true
    focusRetry.begin()
    Qt.callLater(function() {
      root.clampSelection()
      bindingList.positionViewAtIndex(0, ListView.Beginning)
    })
    return true
  }

  function closeHelp() {
    open = false
    focusRetry.stop()
    modalController.release(surfaceName)
    return true
  }

  function toggleHelp() {
    return open ? closeHelp() : openHelp()
  }

  onFilteredEntriesChanged: clampSelection()
  onEntryCountChanged: {
    clampSelection()
    if (open && entryCount === 0) closeHelp()
  }
  onTargetScreenChanged: if (open && !targetScreen) closeHelp()

  Connections {
    target: root.modalController
    function onCloseRequested(surface) {
      if (surface === root.surfaceName) root.closeHelp()
    }
  }

  Ui.WindowFocusRetry {
    id: focusRetry
    panel: helpWindow
    onSucceeded: root.focusKeyboardItem()
  }

  Connections {
    id: helpActivation
    target: helpWindow.contentItem ? helpWindow.contentItem.Window.window : null

    function onActiveChanged() {
      var windowObject = helpActivation.target
      if (!root.open || !windowObject) return
      root.modalController.reportWindowActive(root.surfaceName, windowObject.active)
      if (windowObject.active) Qt.callLater(root.focusKeyboardItem)
    }
  }

  PanelWindow {
    id: helpWindow

    screen: root.targetScreen
    visible: root.open || root.cardOpacity > 0
    focusable: root.open
    aboveWindows: true
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    color: "transparent"
    surfaceFormat.opaque: false
    implicitWidth: 640
    implicitHeight: 520

    onVisibleChanged: if (visible && root.open) focusRetry.begin()

    Binding {
      target: helpWindow.contentItem ? helpWindow.contentItem.Window.window : null
      property: "title"
      value: "quickshell-keybind-help"
      when: target !== null
      restoreMode: Binding.RestoreBindingOrValue
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

          Column {
            spacing: 2

            Text {
              text: "KEYBINDS"
              textFormat: Text.PlainText
              color: ShellStyle.Palette.accent
              font.family: ShellStyle.Metrics.fontFamily
              font.pixelSize: ShellStyle.Metrics.titleSize
              font.weight: Font.DemiBold
            }

            Text {
              text: "Active AwesomeWM shortcuts"
              textFormat: Text.PlainText
              color: ShellStyle.Palette.muted
              font.family: ShellStyle.Metrics.fontFamily
              font.pixelSize: ShellStyle.Metrics.captionSize
            }
          }

          Item { Layout.fillWidth: true }

          Text {
            Layout.alignment: Qt.AlignTop | Qt.AlignRight
            text: root.filteredEntries.length + " / " + root.entryCount
            textFormat: Text.PlainText
            color: ShellStyle.Palette.muted
            font.family: ShellStyle.Metrics.fontFamily
            font.pixelSize: ShellStyle.Metrics.captionSize
          }
        }

        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: 34
          color: ShellStyle.Palette.normalWash
          border.width: 1
          border.color: searchInput.activeFocus
            ? ShellStyle.Palette.accent
            : ShellStyle.Palette.hoverBorder
          radius: ShellStyle.Metrics.cornerRadius

          Text {
            anchors.left: parent.left
            anchors.leftMargin: ShellStyle.Metrics.controlPaddingX
            anchors.verticalCenter: parent.verticalCenter
            visible: searchInput.text.length === 0
            text: "Filter by key, category, or action"
            textFormat: Text.PlainText
            color: ShellStyle.Palette.muted
            font.family: ShellStyle.Metrics.fontFamily
            font.pixelSize: ShellStyle.Metrics.bodySize
          }

          TextInput {
            id: searchInput
            anchors.fill: parent
            anchors.leftMargin: ShellStyle.Metrics.controlPaddingX
            anchors.rightMargin: ShellStyle.Metrics.controlPaddingX
            verticalAlignment: TextInput.AlignVCenter
            clip: true
            color: ShellStyle.Palette.foreground
            selectionColor: ShellStyle.Palette.selectedWash
            selectedTextColor: ShellStyle.Palette.foreground
            font.family: ShellStyle.Metrics.fontFamily
            font.pixelSize: ShellStyle.Metrics.bodySize

            onTextChanged: {
              root.selectedIndex = 0
              bindingList.currentIndex = 0
              if (bindingList.count > 0)
                bindingList.positionViewAtIndex(0, ListView.Beginning)
            }

            Keys.priority: Keys.BeforeItem
            Keys.onPressed: function(event) {
              var control = event.modifiers & Qt.ControlModifier
              if (event.key === Qt.Key_Escape) {
                root.closeHelp()
                event.accepted = true
              } else if (event.key === Qt.Key_Down || (control && event.key === Qt.Key_N)) {
                root.moveSelection(1)
                event.accepted = true
              } else if (event.key === Qt.Key_Up || (control && event.key === Qt.Key_P)) {
                root.moveSelection(-1)
                event.accepted = true
              }
            }
          }
        }

        ListView {
          id: bindingList
          Layout.fillWidth: true
          Layout.fillHeight: true
          clip: true
          spacing: 3
          model: root.filteredEntries
          currentIndex: root.selectedIndex

          delegate: Item {
            id: bindingDelegate
            required property var modelData
            required property int index

            readonly property bool selected: index === root.selectedIndex
            readonly property bool startsGroup: index === 0
              || String(root.filteredEntries[index - 1].group || "") !== String(modelData.group || "")

            width: ListView.view.width
            height: 40 + (startsGroup ? 25 : 0)

            Text {
              visible: bindingDelegate.startsGroup
              anchors.left: parent.left
              anchors.top: parent.top
              text: root.groupLabel(bindingDelegate.modelData.group)
              textFormat: Text.PlainText
              color: ShellStyle.Palette.muted
              font.family: ShellStyle.Metrics.fontFamily
              font.pixelSize: ShellStyle.Metrics.captionSize
              font.weight: Font.DemiBold
              font.letterSpacing: 1
            }

            Rectangle {
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.bottom: parent.bottom
              height: 40
              radius: ShellStyle.Metrics.cornerRadius
              color: bindingDelegate.selected
                ? ShellStyle.Palette.selectedWash
                : rowPointer.containsMouse ? ShellStyle.Palette.hoverWash : ShellStyle.Palette.normalWash
              border.width: bindingDelegate.selected ? 1 : 0
              border.color: ShellStyle.Palette.accent

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: ShellStyle.Metrics.controlPaddingX
                anchors.rightMargin: ShellStyle.Metrics.controlPaddingX
                spacing: ShellStyle.Metrics.panelGap

                Text {
                  Layout.preferredWidth: 190
                  text: bindingDelegate.modelData.combo
                  textFormat: Text.PlainText
                  color: ShellStyle.Palette.accent
                  font.family: ShellStyle.Metrics.fontFamily
                  font.pixelSize: ShellStyle.Metrics.bodySmallSize
                  font.weight: Font.DemiBold
                  elide: Text.ElideRight
                }

                Text {
                  Layout.fillWidth: true
                  text: bindingDelegate.modelData.description
                  textFormat: Text.PlainText
                  color: ShellStyle.Palette.foreground
                  font.family: ShellStyle.Metrics.fontFamily
                  font.pixelSize: ShellStyle.Metrics.bodySmallSize
                  elide: Text.ElideRight
                }
              }

              MouseArea {
                id: rowPointer
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                  root.selectedIndex = bindingDelegate.index
                  bindingList.currentIndex = bindingDelegate.index
                  searchInput.forceActiveFocus(Qt.MouseFocusReason)
                }
              }
            }
          }
        }

        Text {
          Layout.fillWidth: true
          visible: root.filteredEntries.length === 0
          text: root.entryCount === 0 ? "Keybind data is unavailable" : "No matching keybinds"
          textFormat: Text.PlainText
          horizontalAlignment: Text.AlignHCenter
          color: ShellStyle.Palette.muted
          font.family: ShellStyle.Metrics.fontFamily
          font.pixelSize: ShellStyle.Metrics.bodySize
        }

        Text {
          Layout.fillWidth: true
          text: "Up / Down navigate · Ctrl+P / Ctrl+N · Esc close"
          textFormat: Text.PlainText
          horizontalAlignment: Text.AlignHCenter
          color: ShellStyle.Palette.muted
          font.family: ShellStyle.Metrics.fontFamily
          font.pixelSize: ShellStyle.Metrics.captionSize
        }
      }
    }
  }

  IpcHandler {
    target: "keybindHelp"

    function openHelp(): string {
      return root.openHelp() ? "open" : "unavailable"
    }

    function closeHelp(): string {
      root.closeHelp()
      return "closed"
    }

    function toggleHelp(): string {
      if (root.open) {
        root.closeHelp()
        return "closed"
      }
      return root.openHelp() ? "open" : "unavailable"
    }

    function status(): string {
      return JSON.stringify({
        open: root.open,
        focused: root.focused,
        count: root.entryCount,
        filtered: root.filteredEntries.length,
        query: searchInput.text,
        screen: root.targetScreen ? String(root.targetScreen.name || "") : ""
      })
    }
  }
}
