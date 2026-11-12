import QtQuick
import QtQuick.Shapes
import "Palette.js" as P

// A speaker with up to three waves for the level; a red slash when muted.
Item {
  id: root

  property real level: 0.5         // 0..1
  property bool muted: false
  property color color: Theme.text
  property real size: 16           // width

  width: size
  height: size * 0.8

  readonly property int waves: muted ? 0 : (level <= 0.01 ? 0 : (level < 0.34 ? 1 : (level < 0.67 ? 2 : 3)))
  readonly property real cy: height / 2

  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer
    // Speaker.
    ShapePath {
      fillColor: root.muted ? Theme.secondary : root.color
      strokeWidth: -1
      strokeColor: "transparent"
      startX: root.size * 0.04; startY: root.cy - root.size * 0.13
      PathLine { x: root.size * 0.2; y: root.cy - root.size * 0.13 }
      PathLine { x: root.size * 0.42; y: root.cy - root.size * 0.33 }
      PathLine { x: root.size * 0.42; y: root.cy + root.size * 0.33 }
      PathLine { x: root.size * 0.2; y: root.cy + root.size * 0.13 }
      PathLine { x: root.size * 0.04; y: root.cy + root.size * 0.13 }
      PathLine { x: root.size * 0.04; y: root.cy - root.size * 0.13 }
    }
    ShapePath {
      fillColor: "transparent"
      strokeColor: Qt.rgba(root.color.r, root.color.g, root.color.b, root.waves >= 1 ? 1 : 0)
      strokeWidth: root.size * 0.09
      capStyle: ShapePath.RoundCap
      PathAngleArc { centerX: root.size * 0.42; centerY: root.cy; radiusX: root.size * 0.17; radiusY: root.size * 0.17; startAngle: -50; sweepAngle: 100 }
    }
    ShapePath {
      fillColor: "transparent"
      strokeColor: Qt.rgba(root.color.r, root.color.g, root.color.b, root.waves >= 2 ? 1 : 0)
      strokeWidth: root.size * 0.09
      capStyle: ShapePath.RoundCap
      PathAngleArc { centerX: root.size * 0.42; centerY: root.cy; radiusX: root.size * 0.33; radiusY: root.size * 0.33; startAngle: -52; sweepAngle: 104 }
    }
    ShapePath {
      fillColor: "transparent"
      strokeColor: Qt.rgba(root.color.r, root.color.g, root.color.b, root.waves >= 3 ? 1 : 0)
      strokeWidth: root.size * 0.09
      capStyle: ShapePath.RoundCap
      PathAngleArc { centerX: root.size * 0.42; centerY: root.cy; radiusX: root.size * 0.49; radiusY: root.size * 0.49; startAngle: -54; sweepAngle: 108 }
    }
    // Muted: a slash across.
    ShapePath {
      fillColor: "transparent"
      strokeColor: root.muted ? Theme.red : "transparent"
      strokeWidth: root.size * 0.1
      capStyle: ShapePath.RoundCap
      startX: root.size * 0.58; startY: root.cy - root.size * 0.22
      PathLine { x: root.size * 0.94; y: root.cy + root.size * 0.22 }
    }
  }
}
