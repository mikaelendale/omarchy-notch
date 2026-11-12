import QtQuick
import QtQuick.Shapes
import "Palette.js" as P

// Wi-Fi, drawn like a phone's: a wedge and two arcs, lit up to the signal
// strength. Off or disconnected shows all three faint.
Item {
  id: root

  property real strength: 1        // 0..1
  property bool connected: true
  property color color: Theme.text
  property real size: 16           // width; height is 3/4 of it

  width: size
  height: size * 0.78

  readonly property int bars: !connected ? 0 : (strength >= 0.66 ? 3 : (strength >= 0.33 ? 2 : 1))
  readonly property real cx: width / 2
  readonly property real cy: height - size * 0.06
  readonly property real stroke: size * 0.15

  function tone(level) { return Qt.rgba(root.color.r, root.color.g, root.color.b, root.bars >= level ? 1 : 0.3) }

  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer
    // Inner wedge.
    ShapePath {
      fillColor: root.tone(1)
      strokeWidth: -1
      strokeColor: "transparent"
      startX: root.cx
      startY: root.cy
      PathAngleArc { centerX: root.cx; centerY: root.cy; radiusX: root.size * 0.22; radiusY: root.size * 0.22; startAngle: -135; sweepAngle: 90; moveToStart: false }
      PathLine { x: root.cx; y: root.cy }
    }
    ShapePath {
      fillColor: "transparent"
      strokeColor: root.tone(2)
      strokeWidth: root.stroke
      capStyle: ShapePath.RoundCap
      PathAngleArc { centerX: root.cx; centerY: root.cy; radiusX: root.size * 0.47; radiusY: root.size * 0.47; startAngle: -132; sweepAngle: 84 }
    }
    ShapePath {
      fillColor: "transparent"
      strokeColor: root.tone(3)
      strokeWidth: root.stroke
      capStyle: ShapePath.RoundCap
      PathAngleArc { centerX: root.cx; centerY: root.cy; radiusX: root.size * 0.72; radiusY: root.size * 0.72; startAngle: -130; sweepAngle: 80 }
    }
  }
}
