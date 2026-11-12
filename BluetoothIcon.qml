import QtQuick
import QtQuick.Shapes
import "Palette.js" as P

// Bluetooth's rune: bright with a device connected, softer when on, faint off.
Item {
  id: root

  property bool enabled_: true
  property bool connected: false
  property color color: Theme.text
  property real size: 16           // height

  width: size * 0.62
  height: size

  readonly property real a: connected ? 1 : (enabled_ ? 0.75 : 0.3)

  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      fillColor: "transparent"
      strokeColor: Qt.rgba(root.color.r, root.color.g, root.color.b, root.a)
      strokeWidth: root.size * 0.11
      capStyle: ShapePath.RoundCap
      joinStyle: ShapePath.RoundJoin
      startX: root.width * 0.08; startY: root.height * 0.29
      PathLine { x: root.width * 0.9; y: root.height * 0.71 }
      PathLine { x: root.width * 0.5; y: root.height * 0.94 }
      PathLine { x: root.width * 0.5; y: root.height * 0.06 }
      PathLine { x: root.width * 0.9; y: root.height * 0.29 }
      PathLine { x: root.width * 0.08; y: root.height * 0.71 }
    }
  }
}
