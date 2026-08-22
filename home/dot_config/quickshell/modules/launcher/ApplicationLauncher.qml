import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../style" as ShellStyle

Item {
  id: root

  required property QtObject bridge
  required property QtObject modalController

  readonly property string surfaceName: "launcher"
  property bool open: false
  property int selectedIndex: 0
  property string error: ""
  property real cardOpacity: open ? 1 : 0
  property var targetScreen: null
  property int focusAttemptCount: 0

  readonly property int focusAttemptLimit: 8
  readonly property var entries: DesktopEntries.applications.values
  readonly property int entryCount: entries ? entries.length : 0
  readonly property var filteredEntries: filterEntries(searchInput.text)

  Behavior on cardOpacity {
    enabled: !root.modalController.dismissImmediately
    NumberAnimation {
      duration: ShellStyle.Metrics.animationMs
      easing.type: Easing.OutCubic
    }
  }

  function resolveTargetScreen() {
    var outputIds = []
    if (bridge) {
      var focused = String(bridge.focusedOutput || "")
      var primary = String(bridge.primaryOutput || "")
      if (focused) outputIds.push(focused)
      if (primary && outputIds.indexOf(primary) === -1) outputIds.push(primary)
    }
    for (var outputIndex = 0; outputIndex < outputIds.length; outputIndex++) {
      var outputId = outputIds[outputIndex]
      var outputName = outputId
      var outputs = bridge && Array.isArray(bridge.outputs) ? bridge.outputs : []
      for (var mapIndex = 0; mapIndex < outputs.length; mapIndex++) {
        if (String(outputs[mapIndex].id || "") === outputId) {
          outputName = String(outputs[mapIndex].name || outputId)
          break
        }
      }
      for (var screenIndex = 0; screenIndex < Quickshell.screens.length; screenIndex++) {
        var candidate = Quickshell.screens[screenIndex]
        if (candidate && String(candidate.name || "") === outputName) return candidate
      }
    }
    for (var fallbackIndex = 0; fallbackIndex < Quickshell.screens.length; fallbackIndex++)
      if (Quickshell.screens[fallbackIndex]) return Quickshell.screens[fallbackIndex]
    return null
  }

  function iconSource(entry) {
    var requested = String(entry && entry.icon || "")
    var resolved = requested ? Quickshell.iconPath(requested, true) : ""
    if (resolved) return resolved
    return Quickshell.iconPath("application-x-executable", true)
  }

  function listText(values) {
    if (!values) return ""
    var parts = []
    for (var i = 0; i < values.length; i++) parts.push(String(values[i] || ""))
    return parts.join(" ")
  }

  function entryFields(entry) {
    return {
      name: String(entry && entry.name || ""),
      genericName: String(entry && entry.genericName || ""),
      comment: String(entry && entry.comment || ""),
      keywords: listText(entry ? entry.keywords : null),
      categories: listText(entry ? entry.categories : null),
      id: String(entry && entry.id || "")
    }
  }

  function entryScore(fields, tokens) {
    var name = fields.name.toLowerCase()
    var genericName = fields.genericName.toLowerCase()
    var comment = fields.comment.toLowerCase()
    var keywords = fields.keywords.toLowerCase()
    var categories = fields.categories.toLowerCase()
    var id = fields.id.toLowerCase()
    var haystack = [name, genericName, comment, keywords, categories, id].join(" ")
    var score = 0

    for (var i = 0; i < tokens.length; i++) {
      var token = tokens[i]
      if (haystack.indexOf(token) === -1) return -1
      if (name === token) score += 0
      else if (name.indexOf(token) === 0) score += 1
      else if (name.indexOf(token) !== -1) score += 2
      else if (genericName.indexOf(token) !== -1) score += 3
      else if (keywords.indexOf(token) !== -1) score += 4
      else if (categories.indexOf(token) !== -1) score += 5
      else if (comment.indexOf(token) !== -1) score += 6
      else score += 7
    }

    return score
  }

  function filterEntries(value) {
    var source = entries || []
    var query = String(value || "").trim().toLowerCase()
    var tokens = query ? query.split(/\s+/) : []
    var ranked = []

    for (var i = 0; i < source.length; i++) {
      var entry = source[i]
      if (!entry || entry.noDisplay || !String(entry.name || "")) continue
      var fields = entryFields(entry)
      var score = entryScore(fields, tokens)
      if (score < 0) continue
      ranked.push({ entry: entry, score: score, name: fields.name.toLowerCase() })
    }

    ranked.sort(function(left, right) {
      if (left.score !== right.score) return left.score - right.score
      return left.name.localeCompare(right.name)
    })

    var result = []
    for (var j = 0; j < ranked.length; j++) result.push(ranked[j].entry)
    return result
  }

  function clampSelection() {
    var count = filteredEntries.length
    if (count === 0) selectedIndex = 0
    else selectedIndex = Math.max(0, Math.min(selectedIndex, count - 1))
  }

  function moveSelection(delta) {
    var count = filteredEntries.length
    if (count === 0) return
    selectedIndex = (selectedIndex + delta + count) % count
    applicationList.currentIndex = selectedIndex
    applicationList.positionViewAtIndex(selectedIndex, ListView.Contain)
  }

  function terminalCommand(entry) {
    var command = entry ? entry.command : null
    var args = ["wezterm", "start"]
    var workingDirectory = String(entry && entry.workingDirectory || "")
    if (workingDirectory) args.push("--cwd", workingDirectory)
    args.push("--")
    if (command) {
      for (var i = 0; i < command.length; i++) args.push(String(command[i]))
    }
    return args
  }

  function launchEntry(entry) {
    if (!entry) return false
    try {
      if (entry.runInTerminal) {
        if (!entry.command || entry.command.length === 0) {
          error = "Terminal application has no executable command"
          return false
        }
        Quickshell.execDetached(terminalCommand(entry))
      } else {
        entry.execute()
      }
      closeLauncher()
      return true
    } catch (launchError) {
      error = String(launchError)
      return false
    }
  }

  function launchSelected() {
    if (filteredEntries.length === 0) return false
    return launchEntry(filteredEntries[selectedIndex])
  }

  function focusKeyboardItem() {
    if (root.open) searchInput.forceActiveFocus(Qt.ShortcutFocusReason)
  }

  function beginKeyboardFocus() {
    focusAttemptCount = 0
    focusRetry.restart()
  }

  function stopKeyboardFocus() {
    focusRetry.stop()
    focusAttemptCount = 0
  }

  function requestKeyboardFocus() {
    if (!root.open || root.modalController.activeSurface !== root.surfaceName) {
      root.stopKeyboardFocus()
      return
    }
    var windowObject = launcherWindow.contentItem
      ? launcherWindow.contentItem.Window.window
      : null
    if (windowObject && launcherWindow.visible && launcherWindow.focusable) {
      if (windowObject.active) {
        root.modalController.reportWindowActive(root.surfaceName, true)
        root.stopKeyboardFocus()
        root.focusKeyboardItem()
        return
      }
      windowObject.requestActivate()
    }

    focusAttemptCount += 1
    if (focusAttemptCount < focusAttemptLimit) {
      focusRetry.restart()
      return
    }

    console.warn("Application launcher could not acquire X11 keyboard focus")
    root.closeLauncher()
  }

  function openLauncher() {
    if (open) {
      beginKeyboardFocus()
      return true
    }
    var resolvedScreen = resolveTargetScreen()
    if (!resolvedScreen) return false
    targetScreen = resolvedScreen
    modalController.activate(surfaceName)
    searchInput.text = ""
    selectedIndex = 0
    error = ""
    open = true
    beginKeyboardFocus()
    Qt.callLater(function() {
      clampSelection()
      applicationList.positionViewAtIndex(selectedIndex, ListView.Beginning)
    })
    return true
  }

  function closeLauncher() {
    open = false
    error = ""
    stopKeyboardFocus()
    modalController.release(surfaceName)
    return true
  }

  function toggleLauncher() {
    return open ? closeLauncher() : openLauncher()
  }

  onFilteredEntriesChanged: clampSelection()

  Connections {
    target: root.modalController
    function onCloseRequested(surface) {
      if (surface === root.surfaceName) root.closeLauncher()
    }
  }

  Timer {
    id: focusRetry
    interval: 60
    repeat: false
    onTriggered: root.requestKeyboardFocus()
  }

  Connections {
    id: launcherActivation
    target: launcherWindow.contentItem ? launcherWindow.contentItem.Window.window : null

    function onActiveChanged() {
      var windowObject = launcherActivation.target
      if (!root.open || !windowObject) return
      root.modalController.reportWindowActive(root.surfaceName, windowObject.active)
      if (windowObject.active) {
        root.stopKeyboardFocus()
        Qt.callLater(root.focusKeyboardItem)
      }
    }
  }

  PanelWindow {
    id: launcherWindow

    screen: root.targetScreen
    visible: root.open || root.cardOpacity > 0
    focusable: root.open
    aboveWindows: true
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    color: "transparent"
    surfaceFormat.opaque: false
    implicitWidth: 560
    implicitHeight: 430

    onVisibleChanged: if (visible && root.open) root.beginKeyboardFocus()

    Binding {
      target: launcherWindow.contentItem ? launcherWindow.contentItem.Window.window : null
      property: "title"
      value: "quickshell-application-launcher"
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
          spacing: ShellStyle.Metrics.labelGap

          Text {
            text: "APPLICATIONS"
            textFormat: Text.PlainText
            color: ShellStyle.Palette.accent
            font.family: ShellStyle.Metrics.fontFamily
            font.pixelSize: ShellStyle.Metrics.titleSize
            font.weight: Font.DemiBold
          }

          Item { Layout.fillWidth: true }

          Text {
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
            text: "Type to filter applications"
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
              applicationList.currentIndex = 0
              if (applicationList.count > 0)
                applicationList.positionViewAtIndex(0, ListView.Beginning)
            }

            Keys.priority: Keys.BeforeItem
            Keys.onPressed: function(event) {
              var control = event.modifiers & Qt.ControlModifier
              if (event.key === Qt.Key_Escape) {
                root.closeLauncher()
                event.accepted = true
              } else if (event.key === Qt.Key_Down || (control && event.key === Qt.Key_N)) {
                root.moveSelection(1)
                event.accepted = true
              } else if (event.key === Qt.Key_Up || (control && event.key === Qt.Key_P)) {
                root.moveSelection(-1)
                event.accepted = true
              } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.launchSelected()
                event.accepted = true
              }
            }
          }
        }

        ListView {
          id: applicationList
          Layout.fillWidth: true
          Layout.fillHeight: true
          clip: true
          spacing: 3
          model: root.filteredEntries
          currentIndex: root.selectedIndex

          delegate: Rectangle {
            id: applicationRow
            required property var modelData
            required property int index

            width: ListView.view.width
            height: 48
            radius: ShellStyle.Metrics.cornerRadius
            color: index === root.selectedIndex
              ? ShellStyle.Palette.selectedWash
              : rowPointer.containsMouse ? ShellStyle.Palette.hoverWash : "transparent"

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: ShellStyle.Metrics.controlPaddingX
              anchors.rightMargin: ShellStyle.Metrics.controlPaddingX
              spacing: ShellStyle.Metrics.controlPaddingX

              Image {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                source: root.iconSource(applicationRow.modelData)
                sourceSize.width: 28
                sourceSize.height: 28
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                smooth: true
              }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                  Layout.fillWidth: true
                  text: String(applicationRow.modelData.name || "Application")
                  textFormat: Text.PlainText
                  color: ShellStyle.Palette.foreground
                  elide: Text.ElideRight
                  font.family: ShellStyle.Metrics.fontFamily
                  font.pixelSize: ShellStyle.Metrics.bodySize
                  font.weight: Font.Medium
                }

                Text {
                  Layout.fillWidth: true
                  text: String(applicationRow.modelData.genericName
                    || applicationRow.modelData.comment
                    || applicationRow.modelData.id
                    || "")
                  textFormat: Text.PlainText
                  color: ShellStyle.Palette.muted
                  elide: Text.ElideRight
                  font.family: ShellStyle.Metrics.fontFamily
                  font.pixelSize: ShellStyle.Metrics.captionSize
                }
              }

              Text {
                visible: !!applicationRow.modelData.runInTerminal
                text: "TERM"
                textFormat: Text.PlainText
                color: ShellStyle.Palette.accent
                font.family: ShellStyle.Metrics.fontFamily
                font.pixelSize: ShellStyle.Metrics.captionSize
                font.weight: Font.DemiBold
              }
            }

            MouseArea {
              id: rowPointer
              anchors.fill: parent
              hoverEnabled: true
              onEntered: root.selectedIndex = applicationRow.index
              onClicked: {
                root.selectedIndex = applicationRow.index
                root.launchEntry(applicationRow.modelData)
              }
            }
          }
        }

        Text {
          Layout.fillWidth: true
          visible: applicationList.count === 0 || root.error.length > 0
          text: root.error.length > 0
            ? root.error
            : root.entryCount === 0 ? "Loading applications" : "No matching applications"
          textFormat: Text.PlainText
          color: root.error.length > 0 ? ShellStyle.Palette.urgent : ShellStyle.Palette.muted
          font.family: ShellStyle.Metrics.fontFamily
          font.pixelSize: ShellStyle.Metrics.bodySmallSize
          horizontalAlignment: Text.AlignHCenter
          elide: Text.ElideRight
        }

        Text {
          Layout.fillWidth: true
          text: "↑ / Ctrl+P  ·  ↓ / Ctrl+N  ·  Enter launch  ·  Esc close"
          textFormat: Text.PlainText
          color: ShellStyle.Palette.muted
          font.family: ShellStyle.Metrics.fontFamily
          font.pixelSize: ShellStyle.Metrics.captionSize
          horizontalAlignment: Text.AlignHCenter
        }
      }
    }
  }

  IpcHandler {
    target: "launcher"

    function toggleLauncher(): string {
      return root.toggleLauncher() ? (root.open ? "open" : "closed") : "unavailable"
    }

    function openLauncher(): string {
      return root.openLauncher() ? "open" : "unavailable"
    }

    function closeLauncher(): string {
      root.closeLauncher()
      return "closed"
    }

    function status(): string {
      return JSON.stringify({
        open: root.open,
        entries: root.entryCount,
        filtered: root.filteredEntries.length,
        focused: searchInput.activeFocus,
        error: root.error
      })
    }
  }
}
