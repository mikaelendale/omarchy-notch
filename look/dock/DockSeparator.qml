import QtQuick
import qs.Commons as Commons

// notch-look: a hairline between the all-apps button and the apps, where the
// two slots meet.
Rectangle {
  property bool vertical: false
  property real slotSize: 48
  property real length: 24

  readonly property color ink: Commons.Color.popups.text

  width: vertical ? length : 1
  height: vertical ? 1 : length
  x: vertical ? Math.round((slotSize - length) / 2) : slotSize - 1
  y: vertical ? slotSize - 1 : Math.round((slotSize - length) / 2)
  color: Qt.rgba(ink.r, ink.g, ink.b, 0.16)
}
