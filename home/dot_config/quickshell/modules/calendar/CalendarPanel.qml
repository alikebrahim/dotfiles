import QtQuick
import Quickshell
import Quickshell.Io
import "../../style" as ShellStyle
import "../../ui" as Ui
import "CalendarModel.js" as CalendarModel

Item {
  id: root

  property var screen: null
  required property QtObject barPopoutController
  property var popoutHost: null
  property bool barVisible: true
  property bool open: false
  property date today: new Date()
  property int viewYear: today.getFullYear()
  property int viewMonth: today.getMonth()

  readonly property string surfaceName: "calendar"
  readonly property string todayKey: CalendarModel.keyForDate(today)
  readonly property date viewDate: new Date(viewYear, viewMonth, 1)
  readonly property bool viewingCurrentMonth: viewYear === today.getFullYear()
    && viewMonth === today.getMonth()
  readonly property int weekStart: CalendarModel.normalizedWeekStart(
    null,
    Qt.locale().firstDayOfWeek
  )
  readonly property var weekdays: CalendarModel.weekdayOrder(weekStart)
  readonly property var weeks: CalendarModel.monthGrid(
    viewYear,
    viewMonth,
    weekStart,
    todayKey
  )
  readonly property real yearDone: CalendarModel.yearProgress(
    today.getFullYear(),
    today.getMonth(),
    today.getDate()
  )
  readonly property int yearDonePercent: CalendarModel.yearProgressPercent(
    today.getFullYear(),
    today.getMonth(),
    today.getDate()
  )

  readonly property int cellWidth: 52
  readonly property int cellHeight: 34
  readonly property int cellSpacing: 2
  readonly property int weekColumnWidth: 32
  readonly property int gutterWidth: 14
  readonly property int gridWidth: weekColumnWidth + gutterWidth
    + cellSpacing * 2 + cellWidth * 7 + cellSpacing * 6

  function goToToday() {
    viewYear = today.getFullYear()
    viewMonth = today.getMonth()
  }

  function moveMonth(delta) {
    var next = CalendarModel.stepMonth(viewYear, viewMonth, delta)
    viewYear = next.year
    viewMonth = next.month
  }

  function moveYear(delta) {
    moveMonth(delta * 12)
  }

  function focusKeyboardItem() {
    if (open) keyboardFocus.forceActiveFocus(Qt.ShortcutFocusReason)
  }

  function requestKeyboardFocus() {
    if (!open) return
    var windowObject = popoutHost && popoutHost.contentItem
      ? popoutHost.contentItem.Window.window
      : null
    if (!windowObject) return
    if (windowObject.active) focusKeyboardItem()
    else windowObject.requestActivate()
  }

  function openCalendar() {
    if (screen === null || !barVisible) return false
    barPopoutController.activate(surfaceName)
    today = clock.date
    goToToday()
    open = true
    return true
  }

  function closeCalendar() {
    open = false
    barPopoutController.release(surfaceName)
    return true
  }

  function toggleCalendar() {
    return open ? closeCalendar() : openCalendar()
  }

  function weekdayLabel(weekday) {
    return String(Qt.locale().dayName(weekday, Locale.ShortFormat))
      .replace(/\.$/, "")
      .toUpperCase()
  }

  onBarVisibleChanged: if (!barVisible && open) closeCalendar()
  onScreenChanged: if (open) closeCalendar()

  Connections {
    target: root.barPopoutController

    function onCloseRequested(popout) {
      if (popout === root.surfaceName) root.closeCalendar()
    }
  }

  SystemClock {
    id: clock
    precision: SystemClock.Minutes

    onDateChanged: {
      if (CalendarModel.keyForDate(date) === root.todayKey) return
      var followToday = root.viewingCurrentMonth
      root.today = date
      if (followToday) root.goToToday()
    }
  }

  Connections {
    target: root.popoutHost
    enabled: root.popoutHost !== null
    function onFocusRequested() {
      if (root.open) root.focusKeyboardItem()
    }
  }

  IpcHandler {
    target: "calendar"

    function openCalendar(): string {
      return root.openCalendar() ? "open" : "unavailable"
    }

    function closeCalendar(): string {
      root.closeCalendar()
      return "closed"
    }

    function toggleCalendar(): string {
      return root.toggleCalendar() ? (root.open ? "open" : "closed") : "unavailable"
    }

    function status(): string {
      return JSON.stringify({
        open: root.open,
        focused: keyboardFocus.activeFocus,
        screen: root.screen ? String(root.screen.name || "") : "",
        viewYear: root.viewYear,
        viewMonth: root.viewMonth + 1,
        today: root.todayKey,
        weekStart: root.weekStart
      })
    }
  }

  Ui.PopupCard {
    id: calendarPopup
    host: root.popoutHost
    placement: "center"
    open: root.open
    animateTransitions: !root.barPopoutController.dismissImmediately
      && !root.barPopoutController.switching
    cardWidth: 560
    cardHeight: contentColumn.implicitHeight + padding * 2
    cardRadius: ShellStyle.Metrics.cornerRadius
    cardColor: ShellStyle.Palette.panel
    borderColor: ShellStyle.Palette.panelBorder

    Item {
      id: keyboardFocus
      anchors.fill: parent
      focus: true

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape) {
            root.closeCalendar()
            event.accepted = true
          } else if (event.key === Qt.Key_Left) {
            root.moveMonth(-1)
            event.accepted = true
          } else if (event.key === Qt.Key_Right) {
            root.moveMonth(1)
            event.accepted = true
          } else if (event.key === Qt.Key_Up) {
            root.moveYear(-1)
            event.accepted = true
          } else if (event.key === Qt.Key_Down) {
            root.moveYear(1)
            event.accepted = true
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.goToToday()
            event.accepted = true
          }
        }

        WheelHandler {
          onWheel: function(event) {
            if (event.angleDelta.y === 0) return
            root.moveMonth(event.angleDelta.y > 0 ? -1 : 1)
          }
        }
      }

      Column {
        id: contentColumn
        width: parent.width
        spacing: ShellStyle.Metrics.rowGap

        Item {
          width: parent.width
          height: 58

          Row {
            id: heroRow
            anchors.centerIn: parent
            spacing: ShellStyle.Metrics.sectionGap

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "󰃭"
              textFormat: Text.PlainText
              color: heroMouse.containsMouse && !root.viewingCurrentMonth
                ? ShellStyle.Palette.accent
                : ShellStyle.Palette.foreground
              font.family: ShellStyle.Metrics.fontFamily
              font.pixelSize: ShellStyle.Metrics.displaySize
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: Qt.formatDate(root.today, "MMMM d")
              textFormat: Text.PlainText
              color: heroMouse.containsMouse && !root.viewingCurrentMonth
                ? ShellStyle.Palette.accent
                : ShellStyle.Palette.foreground
              font.family: ShellStyle.Metrics.fontFamily
              font.pixelSize: ShellStyle.Metrics.displayLargeSize
              font.weight: Font.Bold
            }
          }

          MouseArea {
            id: heroMouse
            anchors.fill: heroRow
            enabled: !root.viewingCurrentMonth
            hoverEnabled: enabled
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.goToToday()
          }
        }

        Item {
          anchors.horizontalCenter: parent.horizontalCenter
          width: root.gridWidth
          height: Math.max(yearLabel.implicitHeight, 12)

          Text {
            id: yearLabel
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.today.getFullYear()
            textFormat: Text.PlainText
            color: ShellStyle.Palette.muted
            font.family: ShellStyle.Metrics.fontFamily
            font.pixelSize: ShellStyle.Metrics.captionSize
            font.letterSpacing: 1
          }

          Text {
            id: yearPercent
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.yearDonePercent + "%"
            textFormat: Text.PlainText
            color: ShellStyle.Palette.foreground
            font.family: ShellStyle.Metrics.fontFamily
            font.pixelSize: ShellStyle.Metrics.captionSize
          }

          Rectangle {
            anchors.left: yearLabel.right
            anchors.right: yearPercent.left
            anchors.leftMargin: ShellStyle.Metrics.sectionGap
            anchors.rightMargin: ShellStyle.Metrics.sectionGap
            anchors.verticalCenter: parent.verticalCenter
            height: 5
            radius: height / 2
            color: ShellStyle.Palette.track

            Rectangle {
              width: Math.round(parent.width * root.yearDone)
              height: parent.height
              radius: parent.radius
              color: ShellStyle.Palette.accent

              Behavior on width {
                NumberAnimation {
                  duration: ShellStyle.Metrics.animationMs
                  easing.type: Easing.OutCubic
                }
              }
            }
          }
        }

        Item {
          anchors.horizontalCenter: parent.horizontalCenter
          width: root.gridWidth
          height: gridColumn.implicitHeight

          Column {
            id: gridColumn
            width: parent.width
            spacing: 3

            Row {
              spacing: root.cellSpacing

              Text {
                width: root.weekColumnWidth
                height: 18
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: "W"
                textFormat: Text.PlainText
                color: ShellStyle.Palette.muted
                font.family: ShellStyle.Metrics.fontFamily
                font.pixelSize: ShellStyle.Metrics.captionSize
                font.weight: Font.Bold
              }

              Item {
                width: root.gutterWidth
                height: 18
              }

              Repeater {
                model: root.weekdays

                Text {
                  required property var modelData
                  width: root.cellWidth
                  height: 18
                  horizontalAlignment: Text.AlignHCenter
                  verticalAlignment: Text.AlignVCenter
                  text: root.weekdayLabel(modelData)
                  textFormat: Text.PlainText
                  color: ShellStyle.Palette.muted
                  font.family: ShellStyle.Metrics.fontFamily
                  font.pixelSize: ShellStyle.Metrics.captionSize
                  font.letterSpacing: 1
                  font.weight: Font.Bold
                }
              }
            }

            Repeater {
              model: root.weeks

              Row {
                required property var modelData
                spacing: root.cellSpacing

                Text {
                  width: root.weekColumnWidth
                  height: root.cellHeight
                  horizontalAlignment: Text.AlignHCenter
                  verticalAlignment: Text.AlignVCenter
                  text: modelData.week
                  textFormat: Text.PlainText
                  color: ShellStyle.Palette.muted
                  opacity: 0.65
                  font.family: ShellStyle.Metrics.fontFamily
                  font.pixelSize: ShellStyle.Metrics.captionSize
                }

                Item {
                  width: root.gutterWidth
                  height: root.cellHeight

                  Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 1
                    height: parent.height
                    color: ShellStyle.Palette.separator
                  }
                }

                Repeater {
                  model: modelData.days

                  Rectangle {
                    required property var modelData

                    width: root.cellWidth
                    height: root.cellHeight
                    radius: ShellStyle.Metrics.cornerRadius
                    color: "transparent"
                    border.width: modelData.today ? 1 : 0
                    border.color: ShellStyle.Palette.accent

                    Text {
                      anchors.centerIn: parent
                      text: modelData.day
                      textFormat: Text.PlainText
                      color: modelData.inMonth
                        ? (modelData.weekend
                          ? Qt.darker(ShellStyle.Palette.foreground, 1.45)
                          : ShellStyle.Palette.foreground)
                        : Qt.darker(ShellStyle.Palette.foreground, 2.2)
                      font.family: ShellStyle.Metrics.fontFamily
                      font.pixelSize: ShellStyle.Metrics.bodySize
                      font.weight: modelData.today ? Font.Bold : Font.Normal
                    }
                  }
                }
              }
            }
          }
        }

        Item {
          anchors.horizontalCenter: parent.horizontalCenter
          width: root.gridWidth
          height: 30

          Rectangle {
            id: previousButton
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 34
            height: 28
            radius: ShellStyle.Metrics.cornerRadius
            color: previousMouse.containsMouse
              ? ShellStyle.Palette.hoverWash
              : "transparent"
            border.width: 1
            border.color: previousMouse.containsMouse
              ? ShellStyle.Palette.hoverBorder
              : ShellStyle.Palette.separator

            Text {
              anchors.centerIn: parent
              text: "‹"
              textFormat: Text.PlainText
              color: ShellStyle.Palette.foreground
              font.family: ShellStyle.Metrics.fontFamily
              font.pixelSize: ShellStyle.Metrics.headingSize
            }

            MouseArea {
              id: previousMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.moveMonth(-1)
            }
          }

          Text {
            anchors.centerIn: parent
            width: 180
            horizontalAlignment: Text.AlignHCenter
            text: Qt.formatDate(root.viewDate, "MMMM yyyy").toUpperCase()
            textFormat: Text.PlainText
            color: ShellStyle.Palette.foreground
            font.family: ShellStyle.Metrics.fontFamily
            font.pixelSize: ShellStyle.Metrics.bodySize
            font.letterSpacing: 1
            font.weight: Font.DemiBold
          }

          Rectangle {
            id: nextButton
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 34
            height: 28
            radius: ShellStyle.Metrics.cornerRadius
            color: nextMouse.containsMouse
              ? ShellStyle.Palette.hoverWash
              : "transparent"
            border.width: 1
            border.color: nextMouse.containsMouse
              ? ShellStyle.Palette.hoverBorder
              : ShellStyle.Palette.separator

            Text {
              anchors.centerIn: parent
              text: "›"
              textFormat: Text.PlainText
              color: ShellStyle.Palette.foreground
              font.family: ShellStyle.Metrics.fontFamily
              font.pixelSize: ShellStyle.Metrics.headingSize
            }

            MouseArea {
              id: nextMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.moveMonth(1)
            }
          }
        }

        Text {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          text: "← / → month  ·  ↑ / ↓ year  ·  Enter today  ·  Esc close"
          textFormat: Text.PlainText
          color: ShellStyle.Palette.muted
          font.family: ShellStyle.Metrics.fontFamily
          font.pixelSize: ShellStyle.Metrics.captionSize
        }
      }
  }
}
