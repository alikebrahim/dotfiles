import QtQml

QtObject {
  id: root

  required property QtObject shellState
  readonly property bool visible: shellState ? shellState.barVisible : false

  function toggle() {
    return shellState ? shellState.toggleBar() : false
  }

  function show() {
    if (shellState) shellState.setBarVisible(true)
  }

  function hide() {
    if (shellState) shellState.setBarVisible(false)
  }
}
