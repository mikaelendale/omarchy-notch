import QtQuick
import qs.Commons
import qs.Commons as Commons

// notch-look: a dot between an app's icon and the screen edge while it has a
// window open, stretched into a short bar for the app you're using.
Rectangle {
  id: dot

  property bool running: false
  property bool focused: false
  property string edge: "bottom"
  property real slotSize: 48
  property real iconInset: 6
  property real shift: 0              // follows the icon when apps step aside in a drag

  readonly property bool vertical: edge === "left" || edge === "right"
  readonly property color ink: Commons.Color.popups.text
  readonly property real thickness: 4
  readonly property real length: focused ? 14 : 4
  // Midway between the icon and the screen edge, counted from the free side.
  readonly property real across: slotSize - iconInset / 2

  width: vertical ? thickness : length
  height: vertical ? length : thickness
  radius: thickness / 2
  x: vertical ? (edge === "right" ? across : slotSize - across) - thickness / 2
    : Math.round(slotSize / 2 - width / 2 + shift)
  y: vertical ? Math.round(slotSize / 2 - height / 2 + shift)
    : (edge === "bottom" ? across : slotSize - across) - thickness / 2
  color: Qt.rgba(ink.r, ink.g, ink.b, focused ? 0.92 : 0.5)
  opacity: running ? 1 : 0
  visible: opacity > 0

  Behavior on width { enabled: !Style.reduceMotion; SpringAnimation { spring: 11; damping: 0.85; epsilon: 0.05 } }
  Behavior on height { enabled: !Style.reduceMotion; SpringAnimation { spring: 11; damping: 0.85; epsilon: 0.05 } }
  Behavior on opacity { NumberAnimation { duration: Style.duration(160); easing.type: Easing.OutCubic } }
  Behavior on color { ColorAnimation { duration: Style.duration(160) } }
}
