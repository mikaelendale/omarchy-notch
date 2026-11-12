import QtQuick
import QtQuick.Shapes
import "Palette.js" as P

// A small ring that closes as the Claude plan's 5-hour limit fills: green,
// then orange past 75%, red past 90%.
Item {
  id: root

  property real percent: 0         // 0..1
  property bool ready: true
  property real size: 16

  width: size
  height: size

  readonly property color tint: !ready ? Theme.secondary : (percent >= 0.9 ? Theme.red : (percent >= 0.75 ? Theme.orange : Theme.green))
  readonly property real stroke: size * 0.16
  readonly property real r: (size - stroke) / 2

  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      fillColor: "transparent"
      strokeColor: Theme.hairline
      strokeWidth: root.stroke
      PathAngleArc { centerX: root.size / 2; centerY: root.size / 2; radiusX: root.r; radiusY: root.r; startAngle: 0; sweepAngle: 360 }
    }
    ShapePath {
      fillColor: "transparent"
      strokeColor: root.tint
      strokeWidth: root.stroke
      capStyle: ShapePath.RoundCap
      PathAngleArc { centerX: root.size / 2; centerY: root.size / 2; radiusX: root.r; radiusY: root.r; startAngle: -90; sweepAngle: Math.max(8, Math.min(1, root.percent) * 360) }
    }
  }
}
