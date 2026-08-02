pragma Singleton
import QtQml

QtObject {
  // Direct X11 adaptation of Omarchy Quattro's default shell.toml tokens.
  readonly property int barHeight: 26
  readonly property int edgeInset: 8
  readonly property int sectionGap: 8
  readonly property int controlGap: 0
  readonly property int panelGap: 14
  readonly property int panelPadding: 14
  readonly property int rowGap: 8
  readonly property int labelGap: 6
  readonly property int controlPaddingX: 10
  readonly property int controlPaddingY: 6
  readonly property int controlHeight: 28
  readonly property int trayIconSlot: 24
  readonly property int trayIconSize: 16
  readonly property int trayMaxSlots: 5
  readonly property int trayMenuWidth: 300
  readonly property int trayMenuRowHeight: 30
  readonly property int trayMenuHeaderHeight: 30
  readonly property int trayMenuMaxRows: 9
  readonly property int mediaLabelMaxWidth: 180
  readonly property int mediaPopupWidth: 340
  readonly property int mediaArtworkSize: 64
  readonly property int mediaSourceRowHeight: 42
  readonly property int mediaSourceMaxRows: 5
  readonly property int notificationToastWidth: 380
  readonly property int notificationToastHeight: 122
  readonly property int notificationToastGap: 8
  readonly property int notificationCardPadding: 10
  readonly property int notificationIconSize: 38
  readonly property int notificationHistoryWidth: 420
  readonly property int notificationHistoryHeight: 520
  readonly property int notificationHistoryRowHeight: 92
  readonly property int notificationHistoryGap: 6
  readonly property int tailscalePopupWidth: 380
  readonly property int tailscalePeerRowHeight: 42
  readonly property int weatherPopupWidth: 400
  readonly property int weatherPopupMaxHeight: 520
  readonly property int weatherMetricHeight: 54
  readonly property int weatherForecastRowHeight: 42
  readonly property int weatherSuggestionHeight: 46
  readonly property int popupWidth: 380
  readonly property int cornerRadius: 6
  readonly property int captionSize: 10
  readonly property int bodySmallSize: 11
  readonly property int bodySize: 12
  readonly property int titleSize: 14
  readonly property int headingSize: 16
  readonly property int displaySize: 24
  readonly property int displayLargeSize: 28
  readonly property int textSize: bodySize
  readonly property int smallTextSize: bodySmallSize
  readonly property int animationMs: 140
  readonly property string fontFamily: "monospace"
}
