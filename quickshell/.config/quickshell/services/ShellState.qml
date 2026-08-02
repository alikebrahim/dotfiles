import QtQml

QtObject {
  id: root

  property bool ready: false
  readonly property bool resident: true
  property bool barVisible: true

  signal barVisibilityChanged(bool visible)

  function setBarVisible(visible) {
    var next = !!visible
    if (barVisible === next) return
    barVisible = next
    barVisibilityChanged(next)
  }

  function toggleBar() {
    setBarVisible(!barVisible)
    return barVisible
  }

  Component.onCompleted: ready = true
}
