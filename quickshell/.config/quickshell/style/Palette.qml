pragma Singleton
import QtQuick

QtObject {
  // Omarchy's foundational palette, with the user's taupe accent retained.
  readonly property color transparent: Qt.rgba(0, 0, 0, 0)
  readonly property color foreground: "#cacccc"
  readonly property color background: "#101315"
  readonly property color muted: "#828a92"
  readonly property color accent: "#d7c9bd"
  readonly property color urgent: "#c97575"
  readonly property color normalWash: "#0acacccc"
  readonly property color hoverWash: "#14cacccc"
  readonly property color selectedWash: "#2ecacccc"
  readonly property color controlBorder: "#66cacccc"
  readonly property color hoverBorder: "#40cacccc"
  readonly property color panel: "#f2101315"
  readonly property color panelBorder: "#b3d7c9bd"
  readonly property color barBackground: panel
  readonly property color barText: foreground
  readonly property color popupBackground: panel
  readonly property color popupText: foreground
  readonly property color tooltipBackground: "#f2181c1f"
  readonly property color tooltipText: foreground
  readonly property color separator: "#24cacccc"
  readonly property color track: "#1fcacccc"
}
