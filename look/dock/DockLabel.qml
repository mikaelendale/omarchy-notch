import QtQuick
import qs.Commons
import qs.Commons as Commons

// notch-look: the app's name in a small frosted pill, just off the dock beside
// the icon the pointer is on. It eases out from the dock as it fades in.
Item {
  id: label

  property string text: ""
  property bool shown: false
  property string edge: "bottom"
  property real slotSize: 48
  property real shift: 0              // follows the icon when apps step aside in a drag
  property real clearance: 12         // from the dock

  readonly property bool vertical: edge === "left" || edge === "right"
  readonly property color base: Commons.Color.popups.background
  readonly property color ink: Commons.Color.popups.text
  readonly property bool dark: 0.2126 * base.r + 0.7152 * base.g + 0.0722 * base.b < 0.5
  // How far it still has to travel out from the dock.
  property real travel: shown ? 0 : 5

  width: pill.width
  height: pill.height
  z: 20
  x: edge === "left" ? slotSize + clearance - travel
    : edge === "right" ? -clearance - width + travel
    : Math.round(slotSize / 2 - width / 2 + shift)
  y: edge === "bottom" ? -clearance - height + travel
    : edge === "top" ? slotSize + clearance - travel
    : Math.round(slotSize / 2 - height / 2 + shift)
  opacity: shown && text !== "" ? 1 : 0
  visible: opacity > 0

  Behavior on travel { enabled: !Style.reduceMotion; NumberAnimation { duration: Style.duration(160); easing.type: Easing.OutCubic } }
  Behavior on opacity { NumberAnimation { duration: Style.duration(label.shown ? 110 : 80); easing.type: Easing.OutCubic } }

  Rectangle {
    id: pill
    width: Math.round(name.implicitWidth + 22)
    height: Math.round(name.implicitHeight + 10)
    radius: height / 2
    color: Qt.rgba(label.base.r, label.base.g, label.base.b, Math.max(label.base.a, 0.94))
    border.width: 1
    border.color: label.dark ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(0, 0, 0, 0.09)

    Text {
      id: name
      anchors.centerIn: parent
      text: label.text
      textFormat: Text.PlainText
      color: label.ink
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      font.weight: Font.Medium
    }
  }
}
