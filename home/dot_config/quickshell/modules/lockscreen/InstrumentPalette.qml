pragma Singleton

import QtQuick

QtObject {
  readonly property color base00: "#020608"
  readonly property color base01: "#050c10"
  readonly property color base02: "#07141a"
  readonly property color base03: "#0a1c23"
  readonly property color base04: "#102a32"
  readonly property color base05: "#1a3d46"
  readonly property color base06: "#2d6570"
  readonly property color base07: "#78909a"
  readonly property color base08: "#a8bac1"
  readonly property color base09: "#70db8a"
  readonly property color base10: "#5bcdd4"
  readonly property color base11: "#6f8fe8"
  readonly property color base12: "#e2aa52"
  readonly property color base13: "#d76565"
  readonly property color base14: "#a786cf"
  readonly property color base15: "#e8f2f3"

  readonly property color background: base00
  readonly property color panel: base02
  readonly property color panelRaised: base03
  readonly property color grid: base04
  readonly property color borderDim: base05
  readonly property color border: base06
  readonly property color muted: base07
  readonly property color secondaryText: base08
  readonly property color nominal: base09
  readonly property color signal: base10
  readonly property color compute: base11
  readonly property color warning: base12
  readonly property color critical: base13
  readonly property color auxiliary: base14
  readonly property color text: base15

  readonly property string monoFamily: "monospace"
}
