import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray as Tray
import "../../ui" as Ui
import "../../style" as ShellStyle

Item {
  id: root

  property var screen: null
  required property QtObject barPopoutController
  property var popoutHost: null
  property string popupMode: ""
  property var selectedTrayItem: null
  property var menuPath: []
  property int selectedIndex: 0

  readonly property string surfaceName: "tray"
  readonly property var activeItems: {
    var values = Tray.SystemTray.items.values
    if (!values) return []
    return [...values].filter(function(item) {
      return item && item.status !== Tray.Status.Passive
    })
  }
  readonly property int activeCount: activeItems.length
  readonly property bool hasOverflow: activeCount > ShellStyle.Metrics.trayMaxSlots
  readonly property int directLimit: hasOverflow
    ? ShellStyle.Metrics.trayMaxSlots - 1
    : ShellStyle.Metrics.trayMaxSlots
  readonly property var directItems: activeItems.slice(0, directLimit)
  readonly property var overflowItems: activeItems.slice(directLimit)
  readonly property int directCount: directItems.length
  readonly property int overflowCount: overflowItems.length
  readonly property var menuEntries: {
    var values = menuOpener.children.values
    return values ? [...values] : []
  }
  readonly property var currentEntries: popupMode === "menu" ? menuEntries : overflowItems
  readonly property int visibleRows: Math.min(
    ShellStyle.Metrics.trayMenuMaxRows,
    Math.max(1, currentEntries.length)
  )
  readonly property int popupHeight: ShellStyle.Metrics.trayMenuHeaderHeight
    + visibleRows * ShellStyle.Metrics.trayMenuRowHeight
    + ShellStyle.Metrics.panelPadding * 2
  readonly property bool menuOpen: trayPopup.open

  implicitWidth: trayRow.implicitWidth
  implicitHeight: ShellStyle.Metrics.barHeight
  visible: activeCount > 0

  function closePopup() {
    trayPopup.open = false
    barPopoutController.release(surfaceName)
  }

  function showPopup(mode) {
    if (screen === null) return false
    barPopoutController.activate(surfaceName)
    popupMode = mode
    trayPopup.open = true
    Qt.callLater(ensureSelection)
    return true
  }

  function openOverflow() {
    if (overflowCount === 0) return false
    if (trayPopup.open && popupMode === "overflow") {
      closePopup()
      return true
    }
    selectedTrayItem = null
    menuPath = []
    selectedIndex = 0
    return showPopup("overflow")
  }

  function openMenu(item) {
    if (!item || !item.hasMenu || !item.menu) return false
    if (trayPopup.open && popupMode === "menu" && selectedTrayItem === item) {
      closePopup()
      return true
    }
    selectedTrayItem = item
    menuPath = [item.menu]
    selectedIndex = 0
    return showPopup("menu")
  }

  function activateTrayItem(item) {
    if (!item) return false
    if (item.onlyMenu && item.hasMenu) return openMenu(item)
    if (barPopoutController.activePopout) barPopoutController.closeActive()
    item.activate()
    return true
  }

  function secondaryActivate(item) {
    if (!item) return false
    if (barPopoutController.activePopout) barPopoutController.closeActive()
    item.secondaryActivate()
    return true
  }

  function forwardScroll(item, delta, horizontal) {
    if (!item || delta === 0) return false
    item.scroll(delta, horizontal)
    return true
  }

  function entrySelectable(index) {
    if (index < 0 || index >= currentEntries.length) return false
    if (popupMode !== "menu") return true
    var entry = currentEntries[index]
    return entry && !entry.isSeparator && entry.enabled
  }

  function ensureSelection() {
    var count = currentEntries.length
    if (count === 0) {
      selectedIndex = 0
      return
    }
    selectedIndex = Math.max(0, Math.min(selectedIndex, count - 1))
    if (entrySelectable(selectedIndex)) {
      popupList.positionViewAtIndex(selectedIndex, ListView.Contain)
      return
    }
    moveSelection(1)
  }

  function moveSelection(delta) {
    var count = currentEntries.length
    if (count === 0) return false
    var direction = delta < 0 ? -1 : 1
    var candidate = selectedIndex
    for (var step = 0; step < count; step++) {
      candidate = (candidate + direction + count) % count
      if (entrySelectable(candidate)) {
        selectedIndex = candidate
        popupList.positionViewAtIndex(selectedIndex, ListView.Contain)
        return true
      }
    }
    return false
  }

  function enterSubmenu(entry) {
    if (!entry || !entry.enabled || !entry.hasChildren) return false
    menuPath = menuPath.concat([entry])
    selectedIndex = 0
    Qt.callLater(ensureSelection)
    return true
  }

  function leaveSubmenu() {
    if (popupMode !== "menu" || menuPath.length <= 1) return false
    menuPath = menuPath.slice(0, menuPath.length - 1)
    selectedIndex = 0
    Qt.callLater(ensureSelection)
    return true
  }

  function activateIndex(index, button) {
    if (index < 0 || index >= currentEntries.length) return false
    selectedIndex = index
    var entry = currentEntries[index]

    if (popupMode === "overflow") {
      if (button === Qt.RightButton) return openMenu(entry)
      if (entry.onlyMenu && entry.hasMenu) return openMenu(entry)
      closePopup()
      entry.activate()
      return true
    }

    if (!entry || entry.isSeparator || !entry.enabled) return false
    if (entry.hasChildren) return enterSubmenu(entry)
    entry.triggered()
    closePopup()
    return true
  }

  function activateSelection() {
    return activateIndex(selectedIndex, Qt.LeftButton)
  }

  function focusKeyboardItem() {
    if (trayPopup.open) keyboardNavigator.forceActiveFocus(Qt.ShortcutFocusReason)
  }

  function requestKeyboardFocus() {
    if (!trayPopup.open) return
    var windowObject = popoutHost && popoutHost.contentItem
      ? popoutHost.contentItem.Window.window
      : null
    if (!windowObject) return
    if (windowObject.active) focusKeyboardItem()
    else windowObject.requestActivate()
  }

  onActiveItemsChanged: {
    if (!trayPopup.open) return
    if (popupMode === "overflow" && overflowCount === 0) closePopup()
    else if (popupMode === "menu" && activeItems.indexOf(selectedTrayItem) === -1) closePopup()
  }
  onMenuEntriesChanged: if (trayPopup.open && popupMode === "menu") Qt.callLater(ensureSelection)
  onScreenChanged: if (trayPopup.open) closePopup()

  RowLayout {
    id: trayRow
    anchors.fill: parent
    spacing: 0

    Repeater {
      model: root.directItems

      delegate: TrayItem {
        required property var modelData
        trayItem: modelData
        barPopoutController: root.barPopoutController
        onPrimaryRequested: function(item) { root.activateTrayItem(item) }
        onMenuRequested: function(item) { root.openMenu(item) }
        onSecondaryRequested: function(item) { root.secondaryActivate(item) }
        onScrollRequested: function(item, delta, horizontal) {
          root.forwardScroll(item, delta, horizontal)
        }
      }
    }

    Item {
      id: overflowButton
      Layout.preferredWidth: root.hasOverflow ? ShellStyle.Metrics.trayIconSlot : 0
      Layout.fillHeight: true
      visible: root.hasOverflow

      Rectangle {
        anchors.centerIn: parent
        width: ShellStyle.Metrics.trayIconSlot - 2
        height: width
        radius: ShellStyle.Metrics.cornerRadius
        color: overflowHover.hovered
          ? ShellStyle.Palette.hoverWash
          : ShellStyle.Palette.transparent
      }

      Text {
        anchors.centerIn: parent
        text: "+" + root.overflowCount
        textFormat: Text.PlainText
        color: ShellStyle.Palette.foreground
        font.family: ShellStyle.Metrics.fontFamily
        font.pixelSize: ShellStyle.Metrics.captionSize
      }

      HoverHandler { id: overflowHover }
      TapHandler {
        acceptedButtons: Qt.LeftButton
        onTapped: root.openOverflow()
      }

      Ui.PopupToolTip {
        anchorItem: overflowButton
        text: root.overflowCount + " more tray item" + (root.overflowCount === 1 ? "" : "s")
        shown: overflowHover.hovered
        barPopoutController: root.barPopoutController
        delay: 500
      }
    }
  }

  QsMenuOpener {
    id: menuOpener
    menu: root.menuPath.length > 0 ? root.menuPath[root.menuPath.length - 1] : null
  }

  Connections {
    target: root.popoutHost
    enabled: root.popoutHost !== null
    function onFocusRequested() {
      if (trayPopup.open) root.focusKeyboardItem()
    }
  }

  Connections {
    target: root.barPopoutController

    function onCloseRequested(popout) {
      if (popout !== root.surfaceName) return
      trayPopup.open = false
    }
  }

  Ui.PopupCard {
    id: trayPopup
    host: root.popoutHost
    anchorItem: root.popupMode === "overflow" ? overflowButton : root
    placement: "anchor"
    animateTransitions: !root.barPopoutController.dismissImmediately
      && !root.barPopoutController.switching
    cardWidth: ShellStyle.Metrics.trayMenuWidth
    cardHeight: root.popupHeight
    cardRadius: ShellStyle.Metrics.cornerRadius
    cardColor: ShellStyle.Palette.panel
    borderColor: ShellStyle.Palette.panelBorder

    onOpenChanged: {
      if (open) {
        root.barPopoutController.activate(root.surfaceName)
      } else {
        root.barPopoutController.release(root.surfaceName)
      }
    }

    Ui.KeyboardNavigator {
      id: keyboardNavigator
      anchors.fill: parent
      onCloseRequested: {
        if (!root.leaveSubmenu()) root.closePopup()
      }
      onMoveRequested: function(dx, dy) {
        if (dx < 0) root.leaveSubmenu()
        else if (dx > 0 && root.popupMode === "menu"
                 && root.currentEntries.length > root.selectedIndex)
          root.enterSubmenu(root.currentEntries[root.selectedIndex])
        else if (dy !== 0) root.moveSelection(dy)
      }
      onActivateRequested: root.activateSelection()
      onTabRequested: function(direction) { root.moveSelection(direction) }
    }

    Text {
      id: popupHeader
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      height: ShellStyle.Metrics.trayMenuHeaderHeight
      verticalAlignment: Text.AlignVCenter
      text: {
        if (root.popupMode === "overflow") return "More tray items"
        var current = root.menuPath.length > 1
          ? root.menuPath[root.menuPath.length - 1]
          : root.selectedTrayItem
        var label = current ? String(current.text || current.title || current.id || "Tray menu") : "Tray menu"
        return root.menuPath.length > 1 ? "‹  " + label : label
      }
      textFormat: Text.PlainText
      elide: Text.ElideRight
      color: ShellStyle.Palette.foreground
      font.family: ShellStyle.Metrics.fontFamily
      font.pixelSize: ShellStyle.Metrics.bodySize
      font.bold: true

      MouseArea {
        anchors.fill: parent
        enabled: root.popupMode === "menu" && root.menuPath.length > 1
        onClicked: root.leaveSubmenu()
      }
    }

    ListView {
      id: popupList
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: popupHeader.bottom
      anchors.bottom: parent.bottom
      clip: true
      model: root.currentEntries
      currentIndex: root.selectedIndex
      boundsBehavior: Flickable.StopAtBounds

      delegate: Item {
        id: entryRow
        required property var modelData
        required property int index

        width: ListView.view.width
        height: root.popupMode === "menu" && modelData.isSeparator
          ? 12
          : ShellStyle.Metrics.trayMenuRowHeight
        readonly property bool selectable: root.popupMode !== "menu"
          || (!modelData.isSeparator && modelData.enabled)
        readonly property bool selected: selectable && index === root.selectedIndex

        Rectangle {
          anchors.fill: parent
          visible: entryRow.selectable
          radius: ShellStyle.Metrics.cornerRadius
          color: entryRow.selected || rowMouse.containsMouse
            ? ShellStyle.Palette.hoverWash
            : ShellStyle.Palette.transparent
        }

        Rectangle {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          height: 1
          visible: root.popupMode === "menu" && entryRow.modelData.isSeparator
          color: ShellStyle.Palette.separator
        }

        Image {
          id: entryIcon
          anchors.left: parent.left
          anchors.leftMargin: 6
          anchors.verticalCenter: parent.verticalCenter
          width: ShellStyle.Metrics.trayIconSize
          height: width
          source: String(entryRow.modelData.icon || "")
          fillMode: Image.PreserveAspectFit
          asynchronous: true
          smooth: true
          visible: entryRow.selectable && source !== "" && status !== Image.Error
        }

        Text {
          id: stateMark
          anchors.left: parent.left
          anchors.leftMargin: 6
          anchors.verticalCenter: parent.verticalCenter
          width: ShellStyle.Metrics.trayIconSize
          visible: root.popupMode === "menu" && entryRow.selectable && !entryIcon.visible
          text: {
            if (entryRow.modelData.buttonType === QsMenuButtonType.CheckBox)
              return entryRow.modelData.checkState === Qt.Checked ? "✓" : ""
            if (entryRow.modelData.buttonType === QsMenuButtonType.RadioButton)
              return entryRow.modelData.checkState === Qt.Checked ? "●" : "○"
            return ""
          }
          textFormat: Text.PlainText
          color: ShellStyle.Palette.foreground
          font.family: ShellStyle.Metrics.fontFamily
          font.pixelSize: ShellStyle.Metrics.bodySmallSize
          horizontalAlignment: Text.AlignHCenter
        }

        Text {
          anchors.left: parent.left
          anchors.leftMargin: ShellStyle.Metrics.trayIconSize + 14
          anchors.right: submenuMark.left
          anchors.rightMargin: 6
          anchors.verticalCenter: parent.verticalCenter
          visible: entryRow.selectable
          text: root.popupMode === "menu"
            ? String(entryRow.modelData.text || "")
            : String(entryRow.modelData.title || entryRow.modelData.id || "Tray item")
          textFormat: Text.PlainText
          elide: Text.ElideRight
          color: entryRow.modelData.enabled === false
            ? ShellStyle.Palette.muted
            : ShellStyle.Palette.foreground
          font.family: ShellStyle.Metrics.fontFamily
          font.pixelSize: ShellStyle.Metrics.bodySmallSize
        }

        Text {
          id: submenuMark
          anchors.right: parent.right
          anchors.rightMargin: 8
          anchors.verticalCenter: parent.verticalCenter
          width: 12
          visible: root.popupMode === "menu" && entryRow.selectable
            && entryRow.modelData.hasChildren
          text: "›"
          textFormat: Text.PlainText
          color: ShellStyle.Palette.muted
          font.family: ShellStyle.Metrics.fontFamily
          font.pixelSize: ShellStyle.Metrics.bodySize
          horizontalAlignment: Text.AlignRight
        }

        MouseArea {
          id: rowMouse
          anchors.fill: parent
          visible: entryRow.selectable
          hoverEnabled: true
          acceptedButtons: Qt.LeftButton | Qt.RightButton
          onEntered: root.selectedIndex = entryRow.index
          onClicked: function(mouse) { root.activateIndex(entryRow.index, mouse.button) }
        }
      }

      Text {
        anchors.centerIn: parent
        visible: root.currentEntries.length === 0
        text: root.popupMode === "menu" ? "Loading menu…" : "No overflow items"
        textFormat: Text.PlainText
        color: ShellStyle.Palette.muted
        font.family: ShellStyle.Metrics.fontFamily
        font.pixelSize: ShellStyle.Metrics.bodySmallSize
      }
    }
  }
}
